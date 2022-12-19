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
        Sequel.as(:service_instances__space_id, :space_id),
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
      ).freeze

      SERVICE_BINDING_VIEW = Sequel::Model(:service_bindings).select(
        Sequel.as(:service_bindings__id, :id),
        Sequel.as(:service_bindings__guid, :guid),
        Sequel.as(Types::SERVICE_BINDING, :type),
        Sequel.as(:spaces__id, :space_id),
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
      end.from_self.freeze

      class View < Sequel::Model(VIEW)
        plugin :single_table_inheritance,
          :type,
          model_map: {
            'app' => 'VCAP::CloudController::ServiceBinding',
            'key' => 'VCAP::CloudController::ServiceKey'
          }

        # Custom eager loading: https://github.com/jeremyevans/sequel/blob/master/doc/advanced_associations.rdoc#label-Custom+Eager+Loaders
        many_to_one :service_instance_sti_eager_load,
          dataset: -> { raise 'Must be used for eager loading' },
          eager_loader_key: nil, # set up id_map ourselves
          eager_loader: proc { |eo|
            service_instance_id_to_keys = {}
            service_instance_guid_to_bindings = {}
            eo[:rows].each do |scb|
              scb.associations[:service_instance] = nil
              case scb # keys are joined by ID and bindings by GUID
              when ServiceKey
                service_instance_id_to_keys[scb.service_instance_id] ||= []
                service_instance_id_to_keys[scb.service_instance_id] << scb
              when ServiceBinding
                service_instance_guid_to_bindings[scb.service_instance_guid] ||= []
                service_instance_guid_to_bindings[scb.service_instance_guid] << scb
              end
            end
            ds = ServiceInstance.where(id: service_instance_id_to_keys.keys).or(guid: service_instance_guid_to_bindings.keys)
            ds = ds.eager(eo[:associations]) if eo[:associations]
            ds = eo[:eager_block].call(ds) if eo[:eager_block]
            ds.all do |service_instance|
              service_instance_id_to_keys[service_instance.id]&.each { |binding| binding.associations[:service_instance] = service_instance }
              service_instance_guid_to_bindings[service_instance.guid]&.each { |binding| binding.associations[:service_instance] = service_instance }
            end
          }

        # Custom eager loading: https://github.com/jeremyevans/sequel/blob/master/doc/advanced_associations.rdoc#label-Custom+Eager+Loaders
        one_to_many :labels_sti_eager_load,
          dataset: -> { raise 'Must be used for eager loading' },
          eager_loader_key: nil, # set up id_map ourselves
          eager_loader: proc { |eo|
            service_keys = {}
            service_bindings = {}
            eo[:rows].each do |scb|
              scb.associations[:labels] = []
              case scb
              when ServiceKey
                service_keys[scb.guid] = scb
              when ServiceBinding
                service_bindings[scb.guid] = scb
              end
            end
            ServiceKeyLabelModel.where(resource_guid: service_keys.keys).all do |label|
              service_keys[label.resource_guid].associations[:labels] << label if service_keys[label.resource_guid]
            end
            ServiceBindingLabelModel.where(resource_guid: service_bindings.keys).all do |label|
              service_bindings[label.resource_guid].associations[:labels] << label if service_bindings[label.resource_guid]
            end
          }

        # Custom eager loading: https://github.com/jeremyevans/sequel/blob/master/doc/advanced_associations.rdoc#label-Custom+Eager+Loaders
        one_to_many :annotations_sti_eager_load,
          dataset: -> { raise 'Must be used for eager loading' },
          eager_loader_key: nil, # set up id_map ourselves
          eager_loader: proc { |eo|
            service_keys = {}
            service_bindings = {}
            eo[:rows].each do |scb|
              scb.associations[:annotations] = []
              case scb
              when ServiceKey
                service_keys[scb.guid] = scb
              when ServiceBinding
                service_bindings[scb.guid] = scb
              end
            end
            ServiceKeyAnnotationModel.where(resource_guid: service_keys.keys).all do |annotation|
              service_keys[annotation.resource_guid].associations[:annotations] << annotation if service_keys[annotation.resource_guid]
            end
            ServiceBindingAnnotationModel.where(resource_guid: service_bindings.keys).all do |annotation|
              service_bindings[annotation.resource_guid].associations[:annotations] << annotation if service_bindings[annotation.resource_guid]
            end
          }

        # Custom eager loading: https://github.com/jeremyevans/sequel/blob/master/doc/advanced_associations.rdoc#label-Custom+Eager+Loaders
        one_to_many :operation_sti_eager_load,
          dataset: -> { raise 'Must be used for eager loading' },
          eager_loader_key: nil, # set up id_map ourselves
          eager_loader: proc { |eo|
            service_keys = {}
            service_bindings = {}
            eo[:rows].each do |scb|
              case scb
              when ServiceKey
                scb.associations[:service_key_operation] = nil
                service_keys[scb.id] = scb
              when ServiceBinding
                scb.associations[:service_binding_operation] = nil
                service_bindings[scb.id] = scb
              end
            end
            ServiceKeyOperation.where(service_key_id: service_keys.keys).all do |operation|
              service_keys[operation.service_key_id].associations[:service_key_operation] = operation
            end
            ServiceBindingOperation.where(service_binding_id: service_bindings.keys).all do |operation|
              service_bindings[operation.service_binding_id].associations[:service_binding_operation] = operation
            end
          }
      end
    end

    module ServiceCredentialBindingLabels
      SERVICE_KEY_LABELS_VIEW = Sequel::Model(:service_key_labels).select(
        Sequel.as(:service_key_labels__guid, :guid),
        Sequel.as(:service_key_labels__resource_guid, :resource_guid),
        Sequel.as(:service_key_labels__key_prefix, :key_prefix),
        Sequel.as(:service_key_labels__key_name, :key_name),
        Sequel.as(:service_key_labels__value, :value),
        Sequel.as(ServiceCredentialBinding::Types::SERVICE_KEY, :type),
      )

      SERVICE_BINDING_LABELS_VIEW = Sequel::Model(:service_binding_labels).select(
        Sequel.as(:service_binding_labels__guid, :guid),
        Sequel.as(:service_binding_labels__resource_guid, :resource_guid),
        Sequel.as(:service_binding_labels__key_prefix, :key_prefix),
        Sequel.as(:service_binding_labels__key_name, :key_name),
        Sequel.as(:service_binding_labels__value, :value),
        Sequel.as(ServiceCredentialBinding::Types::SERVICE_BINDING, :type),
      )

      VIEW = [
        SERVICE_KEY_LABELS_VIEW,
        SERVICE_BINDING_LABELS_VIEW
      ].inject do |statement, sub_select|
        statement.union(sub_select, all: true)
      end.freeze

      class View < Sequel::Model(VIEW)
        plugin :single_table_inheritance,
          :type,
          model_map: {
            'app' => 'VCAP::CloudController::ServiceBindingLabels',
            'key' => 'VCAP::CloudController::ServiceKeyLabels'
          }
      end
    end
  end
end
