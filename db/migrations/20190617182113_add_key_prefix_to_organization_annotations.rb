Sequel.migration do
  change do
    unless self[:organization_annotations].columns.include?(:key_prefix)
      alter_table(:organization_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
