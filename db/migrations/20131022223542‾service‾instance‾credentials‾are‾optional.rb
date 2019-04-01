Sequel.migration do
  change do
    alter_table :service_instances do
      set_column_allow_null :credentials
    end
  end
end
