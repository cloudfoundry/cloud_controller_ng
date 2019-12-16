Sequel.migration do
  change do
    create_table(:service_broker_update_request_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :sb_update_request_labels, :service_broker_update_requests)
    end

    create_table(:service_broker_update_request_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :sb_update_request_annotations, :service_broker_update_requests)
    end
  end
end
