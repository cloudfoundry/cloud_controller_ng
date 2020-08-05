module VCAP
  module CloudController
    module ServiceCredentialBinding
      module Types
        SERVICE_KEY = 'key'.freeze
        SERVICE_BINDING = 'app'.freeze
      end

      SERVICE_KEY_VIEW = Sequel::Model(:service_keys).select(
        Sequel.as(:service_keys__guid, :guid),
        Sequel.as(Types::SERVICE_KEY, :type),
        Sequel.as(:spaces__guid, :space_guid),
        Sequel.as(:service_keys__created_at, :created_at),
        Sequel.as(:service_keys__updated_at, :updated_at),
        Sequel.as(:service_keys__name, :name),
        Sequel.as(:service_instances__guid, :service_instance_guid),
        Sequel.as(nil, :app_guid),
        Sequel.as(nil, :last_operation_state),
        Sequel.as(nil, :last_operation_description),
        Sequel.as(nil, :last_operation_created_at),
        Sequel.as(nil, :last_operation_updated_at),
        Sequel.as(nil, :last_operation_type),
        Sequel.as(nil, :last_operation_id)
      ).join(
        :service_instances, id: Sequel[:service_keys][:service_instance_id]
      ).join(
        :spaces, id: Sequel[:service_instances][:space_id]
      ).freeze

      SERVICE_BINDING_VIEW = Sequel::Model(:service_bindings).select(
        Sequel.as(:service_bindings__guid, :guid),
        Sequel.as(Types::SERVICE_BINDING, :type),
        Sequel.as(:spaces__guid, :space_guid),
        Sequel.as(:service_bindings__created_at, :created_at),
        Sequel.as(:service_bindings__updated_at, :updated_at),
        Sequel.as(:service_bindings__name, :name),
        Sequel.as(:service_bindings__service_instance_guid, :service_instance_guid),
        Sequel.as(:service_bindings__app_guid, :app_guid),
        Sequel.as(:service_binding_operations__state, :last_operation_state),
        Sequel.as(:service_binding_operations__description, :last_operation_description),
        Sequel.as(:service_binding_operations__created_at, :last_operation_created_at),
        Sequel.as(:service_binding_operations__updated_at, :last_operation_updated_at),
        Sequel.as(:service_binding_operations__type, :last_operation_type),
        Sequel.as(:service_binding_operations__id, :last_operation_id)
      ).join(
        :apps, guid: Sequel[:service_bindings][:app_guid]
      ).join(
        :spaces, guid: Sequel[:apps][:space_guid]
      ).left_join(
        :service_binding_operations, service_binding_id: Sequel[:service_bindings][:id]
      ).freeze

      VIEW = [
        SERVICE_KEY_VIEW,
        SERVICE_BINDING_VIEW
      ].inject do |statement, sub_select|
        statement.union(sub_select, all: true, from_self: false)
      end.from_self.freeze

      class View < Sequel::Model(VIEW)
      end
    end
  end
end
