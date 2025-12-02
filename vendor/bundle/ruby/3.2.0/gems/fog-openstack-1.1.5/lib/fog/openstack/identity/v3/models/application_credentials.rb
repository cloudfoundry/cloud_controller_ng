require 'fog/openstack/models/collection'
require 'fog/openstack/identity/v3/models/os_credential'

module Fog
  module OpenStack
    class Identity
      class V3
        class ApplicationCredentials < Fog::OpenStack::Collection
          model Fog::OpenStack::Identity::V3::ApplicationCredential

          def all(options = {})
            load_response(service.list_application_credentials(options), 'application_credentials')
          end

          def find_by_id(id, user_id)
            cached_credential =  all(user_id).find { |application_credential| application_credential.id == id }
            return cached_credential if cached_credential
            credential_hash = service.get_application_credentials(id, user_id).body['application_credential']
            Fog::OpenStack::Identity::V3::ApplicationCredential.new(
              credential_hash.merge(:service => service)
            )
          end

          def destroy(id)
            credential = find_by_id(id)
            credential.destroy
          end
        end
      end
    end
  end
end
