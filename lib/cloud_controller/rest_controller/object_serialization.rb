# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  module ObjectSerialization
    def self.render_json(controller, obj, opts)
      Yajl::Encoder.encode(to_hash(controller, obj, opts), :pretty => true)
    end

    def self.to_hash(controller, obj, opts, depth=0, parents=[])
      rel_hash      = relations_hash(controller, obj, opts, depth, parents)
      entity_hash   = obj.to_hash.merge(rel_hash)

      metadata_hash = {
        "id"  => obj.id,
        "url" => controller.url_for_id(obj.id),
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
        other_controller = VCAP::CloudController.controller_from_name(name)
        q_key = "#{controller.class_basename.underscore}_id"
        res["#{name}_url"] = "/v2/#{name}?q=#{q_key}:#{obj.id}"

        others = obj.send(name)

        if (others.count <= max_inline &&
            depth < target_depth && !parents.include?(other_controller))
          res[name.to_s] = others.map do |other|
            other_controller = VCAP::CloudController.controller_from_model(other)
            inlined_relations << to_hash(other_controller, other,
                                         opts, depth + 1, parents)
          end
        end
      end

      controller.to_one_relationships.each do |name, attr|
        other_controller = VCAP::CloudController.controller_from_name(name)
        other_id = obj.send("#{name}_id")
        res["#{name}_url"] = "/v2/#{name.to_s.pluralize}/#{other_id}"
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
