module Fog
  module OpenStack
    class Identity < Fog::Service
      autoload :V2, 'fog/openstack/identity/v2'
      autoload :V3, 'fog/openstack/identity/v3'

      def self.new(args = {})
        if args[:openstack_identity_api_version] =~ /(v)*2(\.0)*/i
          Fog::OpenStack::Identity::V2.new(args)
        else
          Fog::OpenStack::Identity::V3.new(args)
        end
      end

      class Mock
        attr_reader :config

        def initialize(options = {})
          @openstack_auth_uri = URI.parse(options[:openstack_auth_url])
          @config = options
        end
      end

      class Real
        include Fog::OpenStack::Core

        def self.not_found_class
          Fog::OpenStack::Identity::NotFound
        end

        def config_service?
          true
        end

        def config
          self
        end

        def default_endpoint_type
          'admin'
        end

        private

        def configure(source)
          source.instance_variables.each do |v|
            instance_variable_set(v, source.instance_variable_get(v))
          end
        end
      end
    end
  end
end
