Sequel.migration do
  change do
    unless self[:route_annotations].columns.include?(:key_prefix)
      alter_table(:route_annotations) do
        add_column :key_prefix, String, size: 253
      end
    end
  end
end
