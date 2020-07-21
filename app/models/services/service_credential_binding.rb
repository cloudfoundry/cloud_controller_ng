module VCAP
  module CloudController
    module ServiceCredentialBindingViews
      module Types
        SERVICE_KEY = 'key'.freeze
        SERVICE_BINDING = 'app'.freeze
      end

      SERVICE_KEY = ServiceKey.select(
        :guid,
        Sequel.as(Types::SERVICE_KEY, :type),
        Sequel.as(Sequel.cast(:service_instance_id, String), :service_instance_id)
      ).freeze

      SERVICE_BINDING = ServiceBinding.select(
        :guid,
        Sequel.as(Types::SERVICE_BINDING, :type),
        Sequel.as(:service_instance_guid, :service_instance_id)
      ).freeze

      VIEW = [
        SERVICE_KEY,
        SERVICE_BINDING
      ].inject do |statement, sub_select|
        statement.union(sub_select, all: true, from_self: false)
      end.freeze
    end

    class ServiceCredentialBinding < Sequel::Model(ServiceCredentialBindingViews::VIEW)
      def service_instance
        ManagedServiceInstance.first("#{service_instance_primary_key}": service_instance_id)
      end

      def service_instance_primary_key
        case type
        when ServiceCredentialBindingViews::Types::SERVICE_BINDING
          :guid
        else
          :id
        end
      end
    end
  end
end
