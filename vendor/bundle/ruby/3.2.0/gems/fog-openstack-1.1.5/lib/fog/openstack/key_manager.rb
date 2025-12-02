module Fog
  module OpenStack
    class KeyManager < Fog::Service
      SUPPORTED_VERSIONS = /v1(\.0)*/

      requires :openstack_auth_url
      recognizes :openstack_auth_token, :openstack_management_url,
                 :persistent, :openstack_service_type, :openstack_service_name,
                 :openstack_tenant, :openstack_tenant_id, :openstack_userid,
                 :openstack_api_key, :openstack_username, :openstack_identity_endpoint,
                 :current_user, :current_tenant, :openstack_region,
                 :openstack_endpoint_type, :openstack_auth_omit_default_port,
                 :openstack_project_name, :openstack_project_id,
                 :openstack_project_domain, :openstack_user_domain, :openstack_domain_name,
                 :openstack_project_domain_id, :openstack_user_domain_id, :openstack_domain_id,
                 :openstack_identity_api_version, :openstack_temp_url_key, :openstack_cache_ttl


      ## MODELS
      #
      model_path 'fog/openstack/key_manager/models'
      model       :secret
      collection  :secrets
      model       :container
      collection  :containers
      model       :acl

      ## REQUESTS

      # secrets
      request_path 'fog/openstack/key_manager/requests'
      request :create_secret
      request :list_secrets
      request :get_secret
      request :get_secret_payload
      request :get_secret_metadata
      request :delete_secret

      # containers
      request :create_container
      request :get_container
      request :list_containers
      request :delete_container

      #ACL
      request :get_secret_acl
      request :update_secret_acl
      request :replace_secret_acl
      request :delete_secret_acl

      request :get_container_acl
      request :update_container_acl
      request :replace_container_acl
      request :delete_container_acl

      class Mock
        def initialize(options = {})
          @openstack_username = options[:openstack_username]
          @openstack_tenant   = options[:openstack_tenant]
          @openstack_auth_uri = URI.parse(options[:openstack_auth_url])

          @auth_token = Fog::Mock.random_base64(64)
          @auth_token_expiration = (Time.now.utc + 86400).iso8601

          management_url = URI.parse(options[:openstack_auth_url])
          management_url.port = 9311
          management_url.path = '/v1'
          @openstack_management_url = management_url.to_s

          @data ||= {:users => {}}
          unless @data[:users].detect { |u| u['name'] == options[:openstack_username] }
            id = Fog::Mock.random_numbers(6).to_s
            @data[:users][id] = {
              'id'       => id,
              'name'     => options[:openstack_username],
              'email'    => "#{options[:openstack_username]}@mock.com",
              'tenantId' => Fog::Mock.random_numbers(6).to_s,
              'enabled'  => true
            }
          end
        end

        def credentials
          {:provider                 => 'openstack',
           :openstack_auth_url       => @openstack_auth_uri.to_s,
           :openstack_auth_token     => @auth_token,
           :openstack_region         => @openstack_region,
           :openstack_management_url => @openstack_management_url}
        end
      end

      class Real
        include Fog::OpenStack::Core

        def self.not_found_class
          Fog::OpenStack::KeyManager::NotFound
        end

        def default_path_prefix
          'v1'
        end

        def default_service_type
          %w[key-manager]
        end
      end
    end
  end
end
