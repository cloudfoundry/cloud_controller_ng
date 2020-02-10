Sequel.migration do
  change do
    create_table(:service_plan_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :service_plan_labels, :service_plans)
    end

    create_table(:service_plan_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :service_plan_annotations, :service_plans)
    end
  end
end
