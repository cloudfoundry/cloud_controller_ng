require 'fog/openstack/models/model'
require 'fog/openstack/models/meta_parent'

module Fog
  module OpenStack
    class Compute
      class Metadatum < Fog::OpenStack::Model
        include Fog::OpenStack::Compute::MetaParent

        identity :key
        attribute :value

        def destroy
          requires :identity
          service.delete_meta(collection_name, @parent.id, key)
          true
        end

        def save
          requires :identity, :value
          service.update_meta(collection_name, @parent.id, key, value)
          true
        end
      end
    end
  end
end
