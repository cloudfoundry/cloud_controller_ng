module VCAP::CloudController
  class ServiceUsageEvent < Sequel::Model
    plugin :serialization

    export_attributes :state, :org_guid, :space_guid, :space_name,
                      :service_instance_guid, :service_instance_name, :service_instance_type,
                      :service_plan_guid, :service_plan_name,
                      :service_guid, :service_label
  end
end
