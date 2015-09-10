module VCAP::CloudController
  class AppUsageEvent < Sequel::Model
    plugin :serialization

    export_attributes :state, :memory_in_mb_per_instance, :instance_count,
      :app_guid, :app_name, :space_guid, :space_name, :org_guid,
      :buildpack_guid, :buildpack_name, :package_state, :parent_app_guid,
      :parent_app_name, :process_type
  end
end
