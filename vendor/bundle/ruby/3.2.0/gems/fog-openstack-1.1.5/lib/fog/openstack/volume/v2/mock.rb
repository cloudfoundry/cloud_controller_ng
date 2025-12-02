module Fog
  module OpenStack
    class Volume
      class V2 < Fog::OpenStack::Volume
        class Mock
          def self.data
            @data ||= Hash.new do |hash, key|
              hash[key] = {
                :users   => {},
                :tenants => {},
                :quota   => {
                  'gigabytes' => 1000,
                  'volumes'   => 10,
                  'snapshots' => 10
                }
              }
            end
          end

          def self.reset
            @data = nil
          end

          def initialize(options = {})
            @openstack_username = options[:openstack_username]
            @openstack_tenant   = options[:openstack_tenant]
            @openstack_auth_uri = URI.parse(options[:openstack_auth_url])

            @auth_token            = Fog::Mock.random_base64(64)
            @auth_token_expiration = (Time.now.utc + 86400).iso8601

            management_url            = URI.parse(options[:openstack_auth_url])
            management_url.port       = 8776
            management_url.path       = '/v1'
            @openstack_management_url = management_url.to_s

            @data ||= {:users => {}}
            unless @data[:users].find { |u| u['name'] == options[:openstack_username] }
              id                = Fog::Mock.random_numbers(6).to_s
              @data[:users][id] = {
                'id'       => id,
                'name'     => options[:openstack_username],
                'email'    => "#{options[:openstack_username]}@mock.com",
                'tenantId' => Fog::Mock.random_numbers(6).to_s,
                'enabled'  => true
              }
            end
          end

          def data
            self.class.data[@openstack_username]
          end

          def reset_data
            self.class.data.delete(@openstack_username)
          end

          def credentials
            {:provider                 => 'openstack',
             :openstack_auth_url       => @openstack_auth_uri.to_s,
             :openstack_auth_token     => @auth_token,
             :openstack_management_url => @openstack_management_url}
          end
        end
      end
    end
  end
end
