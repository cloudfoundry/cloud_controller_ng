Sequel.migration do
  change do
    alter_table(:service_plans) do
      set_column_allow_null :unique_id
    end

    alter_table(:services) do
      set_column_allow_null :unique_id
    end
  end
end
