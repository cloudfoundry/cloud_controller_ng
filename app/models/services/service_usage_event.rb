module VCAP::CloudController
  class ServiceUsageEvent < Sequel::Model
    plugin :serialization

    one_to_many :consumers,
                class: 'VCAP::CloudController::ServiceUsageConsumer',
                key: :last_processed_guid,
                primary_key: :guid

    add_association_dependencies consumers: :destroy

    export_attributes :state, :org_guid, :space_guid, :space_name,
                      :service_instance_guid, :service_instance_name, :service_instance_type,
                      :service_plan_guid, :service_plan_name,
                      :service_guid, :service_label,
                      :service_broker_name, :service_broker_guid
  end
end
