Sequel.migration do
  change do
    alter_table(:service_instances) do
      set_column_default(:credentials,'')
    end
  end
end
