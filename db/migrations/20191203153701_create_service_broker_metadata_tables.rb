Sequel.migration do
  change do
    create_table(:service_broker_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :service_broker_labels, :service_brokers)
    end

    create_table(:service_broker_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :service_broker_annotations, :service_brokers)
    end
  end
end
