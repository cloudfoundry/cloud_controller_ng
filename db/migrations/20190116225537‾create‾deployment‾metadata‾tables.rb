Sequel.migration do
  change do
    create_table(:deployment_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :deployment_annotations, :deployments)
    end

    create_table(:deployment_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :deployment_labels, :deployments)
    end
  end
end
