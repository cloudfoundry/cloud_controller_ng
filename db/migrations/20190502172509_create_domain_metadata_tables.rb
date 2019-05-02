Sequel.migration do
  change do
    create_table(:domain_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :domain_labels, :domains)
    end

    create_table(:domain_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :domain_annotations, :domains)
    end
  end
end
