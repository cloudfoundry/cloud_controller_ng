require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Identity
      class V3
        class ApplicationCredential < Fog::OpenStack::Model
          identity :id

          attribute :description
          attribute :name
          attribute :roles
          attribute :expires_at
          attribute :user_id
          attribute :secret
          
          class << self
            attr_accessor :cache
          end

          @cache = {}

          def to_s
            id.to_s
          end

          def destroy
            requires :id
            service.delete_application_credentials(id, user_id)
            true
          end

          def create
            merge_attributes(
              service.create_application_credentials(attributes).body['application_credential']
            )
            self
          end
        end
      end
    end
  end
end
