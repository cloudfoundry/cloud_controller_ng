module VCAP::CloudController
  class AppUsageEvent < Sequel::Model
    plugin :serialization

    one_to_many :consumers,
                class: 'VCAP::CloudController::AppUsageConsumer',
                key: :last_processed_guid,
                primary_key: :guid

    add_association_dependencies consumers: :destroy

    export_attributes :state, :previous_state,
                      :memory_in_mb_per_instance, :previous_memory_in_mb_per_instance,
                      :instance_count, :previous_instance_count,
                      :app_guid, :app_name, :space_guid, :space_name, :org_guid,
                      :buildpack_guid, :buildpack_name,
                      :package_state, :previous_package_state, :parent_app_guid,
                      :parent_app_name, :process_type, :task_name, :task_guid
    AppUsageEvent.dataset_module do
      def supports_window_functions?
        false
      end
    end
  end
end
