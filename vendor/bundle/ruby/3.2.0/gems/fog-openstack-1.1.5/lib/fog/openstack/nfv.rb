require 'yaml'

module Fog
  module OpenStack
    class NFV < Fog::Service
      SUPPORTED_VERSIONS = /v1.0/

      requires :openstack_auth_url
      recognizes :openstack_auth_token, :openstack_management_url,
                 :persistent, :openstack_service_type, :openstack_service_name,
                 :openstack_tenant, :openstack_tenant_id,
                 :openstack_api_key, :openstack_username, :openstack_identity_endpoint,
                 :current_user, :current_tenant, :openstack_region,
                 :openstack_endpoint_type,
                 :openstack_project_name, :openstack_project_id,
                 :openstack_project_domain, :openstack_user_domain, :openstack_domain_name,
                 :openstack_project_domain_id, :openstack_user_domain_id, :openstack_domain_id,
                 :openstack_identity_api_version

      ## REQUESTS
      #
      request_path 'fog/openstack/nfv/requests'

      # vnfds requests
      request :list_vnfds
      request :get_vnfd
      request :create_vnfd
      request :delete_vnfd

      # vfns requests
      request :list_vnfs
      request :get_vnf
      request :create_vnf
      request :update_vnf
      request :delete_vnf

      ## MODELS
      #
      model_path 'fog/openstack/nfv/models'
      model       :vnfd
      collection  :vnfds
      model       :vnf
      collection  :vnfs

      class Mock
        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {
              :vnfs  => [
                {
                  "status"      => "ACTIVE",
                  "description" => "demo-example",
                  "tenant_id"   => "943b6ff8229a4ec2bed0a306f869a0ea",
                  "instance_id" => "5a9a7d3b-24f5-4226-8d43-262972a1776e",
                  "mgmt_url"    => "{\"vdu1\": \"192.168.0.8\"}",
                  "attributes"  => {"monitoring_policy" => "{\"vdus\": {}}"},
                  "id"          => "cb4cdbd8-cf1a-4758-8d36-40db788a37a1",
                  "name"        => "LadasTest"
                }
              ],
              :vnfds => [
                {
                  "service_types" => [{"service_type" => "vnfd", "id" => "f9211d81-b58a-4849-8d38-e25376c421bd"}],
                  "description"   => "demo-example",
                  "tenant_id"     => "943b6ff8229a4ec2bed0a306f869a0ea",
                  "mgmt_driver"   => "noop",
                  "infra_driver"  => "heat",
                  "attributes"    => {"vnfd" => "template_name: sample-vnfd"},
                  "id"            => "1f8f33cf-8c94-427e-a040-f3e393b773b7",
                  "name"          => "sample-vnfd"
                }
              ]
            }
          end
        end

        def self.reset
          @data = nil
        end

        include Fog::OpenStack::Core

        def initialize(options = {})
          @auth_token = Fog::Mock.random_base64(64)
          @auth_token_expiration = (Time.now.utc + 86_400).iso8601
        end

        def data
          self.class.data[@openstack_username]
        end

        def reset_data
          self.class.data.delete(@openstack_username)
        end
      end

      class Real
        include Fog::OpenStack::Core

        def self.not_found_class
          Fog::OpenStack::NFV::NotFound
        end

        def default_path_prefix
          'v1.0'
        end

        def default_service_type
          %w[servicevm]
        end
      end
    end
  end
end
