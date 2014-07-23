Sequel.migration do
  change do
    add_column :quota_definitions, :instance_memory_limit, Fixnum, null: false, default: -1
  end
end
