# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController

  # FIXME: add authz checks to attribures and inlined relations
  module ObjectSerialization
    def self.render_json(controller, obj, opts)
      Yajl::Encoder.encode(to_hash(controller, obj, opts), :pretty => true)
    end

    def self.to_hash(controller, obj, opts, depth=0, parents=[])
      rel_hash      = relations_hash(controller, obj, opts, depth, parents)
      entity_hash   = obj.to_hash.merge(rel_hash)

      id = obj.guid || obj.id
      metadata_hash = {
        "id"  => id,
        "url" => controller.url_for_id(id),
        "created_at" => obj.created_at,
        "updated_at" => obj.updated_at
      }

      { "metadata" => metadata_hash, "entity" => entity_hash }
    end

    def self.relations_hash(controller, obj, opts, depth, parents)
      target_depth = opts[:inline_relations_depth] || 0
      max_inline = opts[:max_inline] || 50
      res = {}

      parents.push(controller)

      controller.to_many_relationships.each do |name, attr|
        ar = controller.model.association_reflection(name)
        other_model = ar.associated_class
        other_controller = VCAP::CloudController.controller_from_model_name(other_model.name)
        q_key = if ar[:reciprocol]
                  "#{ar[:reciprocol].to_s.singularize}_id"
                else
                  "#{controller.class_basename.underscore}_id"
                end
        route_name = other_model.name.split("::").last.underscore.pluralize
        res["#{name}_url"] = "/v2/#{route_name}?q=#{q_key}:#{obj.guid}"

        others = obj.send(name)

        if (others.count <= max_inline &&
            depth < target_depth && !parents.include?(other_controller))
          res[name.to_s] = others.map do |other|
            other_controller = VCAP::CloudController.controller_from_model(other)
            to_hash(other_controller, other, opts, depth + 1, parents)
          end
        end
      end

      controller.to_one_relationships.each do |name, attr|
        other_controller = VCAP::CloudController.controller_from_name(name)
        other = obj.send(name)
        res["#{name}_url"] = "/v2/#{name.to_s.pluralize}/#{other.guid}"
        if depth < target_depth && !parents.include?(other_controller)
          other = obj.send(name)
          other_controller = VCAP::CloudController.controller_from_model(other)
          res[name.to_s] = to_hash(other_controller, other,
                                   opts, depth + 1, parents)
        end
      end

      parents.pop
      res
    end
  end
end
