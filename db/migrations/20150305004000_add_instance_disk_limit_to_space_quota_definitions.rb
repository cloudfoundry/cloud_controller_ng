Sequel.migration do
  change do
    alter_table :space_quota_definitions do
      add_column :instance_disk_limit, Fixnum, null: false, default: -1
    end
  end
end
