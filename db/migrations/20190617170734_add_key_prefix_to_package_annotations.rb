Sequel.migration do
  change do
    unless self[:package_annotations].columns.include?(:key_prefix)
      alter_table(:package_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
