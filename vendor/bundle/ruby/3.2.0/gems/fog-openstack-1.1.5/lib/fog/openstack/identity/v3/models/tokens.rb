require 'fog/openstack/models/collection'
require 'fog/openstack/identity/v3/models/service'

module Fog
  module OpenStack
    class Identity
      class V3
        class Tokens < Fog::OpenStack::Collection
          model Fog::OpenStack::Identity::V3::Token

          def authenticate(auth)
            response = service.token_authenticate(auth)
            token_hash = response.body['token']
            Fog::OpenStack::Identity::V3::Token.new(
              token_hash.merge(:service => service, :value => response.headers['X-Subject-Token'])
            )
          end

          def validate(subject_token)
            response = service.token_validate(subject_token)
            token_hash = response.body['token']
            Fog::OpenStack::Identity::V3::Token.new(
              token_hash.merge(:service => service, :value => response.headers['X-Subject-Token'])
            )
          end

          def check(subject_token)
            service.token_check(subject_token)
            true
          end

          def revoke(subject_token)
            service.token_revoke(subject_token)
            true
          end
        end
      end
    end
  end
end
