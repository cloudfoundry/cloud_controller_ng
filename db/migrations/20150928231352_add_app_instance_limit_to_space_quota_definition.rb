Sequel.migration do
  change do
    add_column :space_quota_definitions, :app_instance_limit, Fixnum, default: -1
  end
end
