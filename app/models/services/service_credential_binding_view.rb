module VCAP
  module CloudController
    module ServiceCredentialBinding
      module Types
        SERVICE_KEY = 'key'.freeze
        SERVICE_BINDING = 'app'.freeze
      end

      SERVICE_KEY_VIEW = Sequel::Model(:service_keys).select(
        Sequel.as(:service_keys__id, :id),
        Sequel.as(:service_keys__guid, :guid),
        Sequel.as(Types::SERVICE_KEY, :type),
        Sequel.as(:spaces__guid, :space_guid),
        Sequel.as(:service_keys__created_at, :created_at),
        Sequel.as(:service_keys__updated_at, :updated_at),
        Sequel.as(:service_keys__name, :name),
        Sequel.as(:service_keys__credentials, :credentials),
        Sequel.as(:service_keys__salt, :salt),
        Sequel.as(:service_keys__encryption_key_label, :encryption_key_label),
        Sequel.as(:service_keys__encryption_iterations, :encryption_iterations),
        Sequel.as(:service_instances__guid, :service_instance_guid),
        Sequel.as(:service_instances__name, :service_instance_name),
        Sequel.as(nil, :app_guid),
        Sequel.as(nil, :app_name),
        Sequel.as(:service_keys__service_instance_id, :service_instance_id),
        Sequel.as(nil, :syslog_drain_url),
        Sequel.as(nil, :volume_mounts),
        Sequel.as(nil, :volume_mounts_salt),
        Sequel.as(:service_plans__name, :service_plan_name),
        Sequel.as(:service_plans__guid, :service_plan_guid),
        Sequel.as(:services__label, :service_offering_name),
        Sequel.as(:services__guid, :service_offering_guid)
      ).join(
        :service_instances, id: Sequel[:service_keys][:service_instance_id]
      ).left_join(
        :service_plans, id: Sequel[:service_instances][:service_plan_id]
      ).left_join(
        :services, id: Sequel[:service_plans][:service_id]
      ).join(
        :spaces, id: Sequel[:service_instances][:space_id]
      ).freeze

      SERVICE_BINDING_VIEW = Sequel::Model(:service_bindings).select(
        Sequel.as(:service_bindings__id, :id),
        Sequel.as(:service_bindings__guid, :guid),
        Sequel.as(Types::SERVICE_BINDING, :type),
        Sequel.as(:spaces__guid, :space_guid),
        Sequel.as(:service_bindings__created_at, :created_at),
        Sequel.as(:service_bindings__updated_at, :updated_at),
        Sequel.as(:service_bindings__name, :name),
        Sequel.as(:service_bindings__credentials, :credentials),
        Sequel.as(:service_bindings__salt, :salt),
        Sequel.as(:service_bindings__encryption_key_label, :encryption_key_label),
        Sequel.as(:service_bindings__encryption_iterations, :encryption_iterations),
        Sequel.as(:service_bindings__service_instance_guid, :service_instance_guid),
        Sequel.as(:service_instances__name, :service_instance_name),
        Sequel.as(:service_bindings__app_guid, :app_guid),
        Sequel.as(:apps__name, :app_name),
        Sequel.as(nil, :service_instance_id),
        Sequel.as(:service_bindings__syslog_drain_url, :syslog_drain_url),
        Sequel.as(:service_bindings__volume_mounts, :volume_mounts),
        Sequel.as(:service_bindings__volume_mounts_salt, :volume_mounts_salt),
        Sequel.as(:service_plans__name, :service_plan_name),
        Sequel.as(:service_plans__guid, :service_plan_guid),
        Sequel.as(:services__label, :service_offering_name),
        Sequel.as(:services__guid, :service_offering_guid)
      ).join(
        :apps, guid: Sequel[:service_bindings][:app_guid]
      ).join(
        :service_instances, guid: Sequel[:service_bindings][:service_instance_guid]
      ).left_join(
        :service_plans, id: Sequel[:service_instances][:service_plan_id]
      ).left_join(
        :services, id: Sequel[:service_plans][:service_id]
      ).join(
        :spaces, guid: Sequel[:apps][:space_guid]
      ).freeze

      VIEW = [
        SERVICE_KEY_VIEW,
        SERVICE_BINDING_VIEW
      ].inject do |statement, sub_select|
        statement.union(sub_select, all: true, from_self: false)
      end.from_self.order_by(:created_at).freeze

      class View < Sequel::Model(VIEW)
        plugin :single_table_inheritance,
               :type,
               model_map: {
                 'app' => 'VCAP::CloudController::ServiceBinding',
                 'key' => 'VCAP::CloudController::ServiceKey'
               }
      end
    end
  end
end
