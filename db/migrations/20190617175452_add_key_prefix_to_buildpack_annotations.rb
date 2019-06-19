Sequel.migration do
  change do
    unless self[:buildpack_annotations].columns.include?(:key_prefix)
      alter_table(:buildpack_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
