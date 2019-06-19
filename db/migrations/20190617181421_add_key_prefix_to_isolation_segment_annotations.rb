Sequel.migration do
  change do
    unless self[:isolation_segment_annotations].columns.include?(:key_prefix)
      alter_table(:isolation_segment_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
