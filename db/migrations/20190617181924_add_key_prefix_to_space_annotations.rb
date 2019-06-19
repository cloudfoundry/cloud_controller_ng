Sequel.migration do
  change do
    unless self[:space_annotations].columns.include?(:key_prefix)
      alter_table(:space_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
