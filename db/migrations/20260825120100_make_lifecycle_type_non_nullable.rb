Sequel.migration do
  up do
    alter_table(:apps)     { set_column_not_null :lifecycle_type }
    alter_table(:droplets) { set_column_not_null :lifecycle_type }
    alter_table(:builds)   { set_column_not_null :lifecycle_type }
  end

  down do
    alter_table(:apps)     { set_column_allow_null :lifecycle_type }
    alter_table(:droplets) { set_column_allow_null :lifecycle_type }
    alter_table(:builds)   { set_column_allow_null :lifecycle_type }
  end
end
