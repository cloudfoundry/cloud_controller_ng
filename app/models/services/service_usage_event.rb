module VCAP::CloudController
  class ServiceUsageEvent < Sequel::Model
    plugin :serialization

    export_attributes :state, :org_guid, :space_guid, :space_name,
                      :service_instance_guid, :service_instance_name, :service_instance_type,
                      :service_plan_guid, :service_plan_name,
                      :service_guid, :service_label,
                      :service_broker_name, :service_broker_guid

    def self.usage_lifecycle
      {
        beginning_state: Repositories::ServiceUsageEventRepository::CREATED_EVENT_STATE,
        ending_state: Repositories::ServiceUsageEventRepository::DELETED_EVENT_STATE,
        guid_column: :service_instance_guid
      }.freeze
    end
  end
end
