require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class DNS
      class V2
        class Pool < Fog::OpenStack::Model
          identity :id

          attribute :name
          attribute :description
          attribute :ns_records
          attribute :project_id
          attribute :links
          attribute :created_at
          attribute :updated_at
        end
      end
    end
  end
end
