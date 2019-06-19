Sequel.migration do
  change do
    unless self[:build_annotations].columns.include?(:key_prefix)
      alter_table(:build_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
