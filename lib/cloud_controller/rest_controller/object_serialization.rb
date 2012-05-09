# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  module ObjectSerialization
    def self.render_json(controller, obj)
      Yajl::Encoder.encode(to_hash(controller, obj), :pretty => true)
    end

    def self.to_hash(controller, obj)
      rel_hash      = relations_hash(controller, obj)
      entity_hash   = obj.to_hash.merge(rel_hash)

      metadata_hash = {
        "id"  => obj.id,
        "url" => controller.url_for_id(obj.id),
        "created_at" => obj.created_at,
        "updated_at" => obj.updated_at
      }

      { "metadata" => metadata_hash, "entity" => entity_hash }
    end

    def self.relations_hash(controller, obj)
      res = {}
      # FIXME: to_one also
      controller.to_many_relationships.each do |name, attr|
        key = "#{controller.class_basename.underscore}_id"
        res["#{name}_url"] = "/v2/#{name}?q=#{key}:#{obj.id}"
      end
      res
    end
  end
end
