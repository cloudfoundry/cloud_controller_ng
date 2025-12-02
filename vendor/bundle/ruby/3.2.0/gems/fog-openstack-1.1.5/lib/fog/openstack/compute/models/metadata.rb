require 'fog/openstack/models/collection'
require 'fog/openstack/models/meta_parent'
require 'fog/openstack/compute/models/metadatum'
require 'fog/openstack/compute/models/image'
require 'fog/openstack/compute/models/server'

module Fog
  module OpenStack
    class Compute
      class Metadata < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::Metadatum

        include Fog::OpenStack::Compute::MetaParent

        def all
          requires :parent
          metadata = service.list_metadata(collection_name, @parent.id).body['metadata']
          metas = []
          metadata.each_pair { |k, v| metas << {"key" => k, "value" => v} } unless metadata.nil?
          # TODO: convert to load_response?
          load(metas)
        end

        def get(key)
          requires :parent
          data = service.get_metadata(collection_name, @parent.id, key).body["meta"]
          metas = []
          data.each_pair { |k, v| metas << {"key" => k, "value" => v} }
          new(metas[0])
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end

        def update(data = nil)
          requires :parent
          service.update_metadata(collection_name, @parent.id, to_hash(data))
        end

        def set(data = nil)
          requires :parent
          service.set_metadata(collection_name, @parent.id, to_hash(data))
        end

        def new(attributes = {})
          requires :parent
          super({:parent => @parent}.merge!(attributes))
        end

        def to_hash(data = nil)
          if data.nil?
            data = {}
            each do |meta|
              if meta.kind_of?(Fog::OpenStack::Compute::Metadatum)
                data.store(meta.key, meta.value)
              else
                data.store(meta["key"], meta["value"])
              end
            end
          end
          data
        end
      end
    end
  end
end
