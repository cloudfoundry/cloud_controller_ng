Sequel.migration do
  change do
    create_table(:isolation_segment_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :isolation_segment_annotations, :isolation_segments)
    end

    create_table(:isolation_segment_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :isolation_segment_labels, :isolation_segments)
    end
  end
end
