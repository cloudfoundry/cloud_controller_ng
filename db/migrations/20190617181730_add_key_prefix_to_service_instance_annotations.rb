Sequel.migration do
  change do
    unless self[:service_instance_annotations].columns.include?(:key_prefix)
      alter_table(:service_instance_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
