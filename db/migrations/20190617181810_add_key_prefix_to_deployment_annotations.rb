Sequel.migration do
  change do
    unless self[:deployment_annotations].columns.include?(:key_prefix)
      alter_table(:deployment_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
