Sequel.migration do
  change do
    alter_table(:app_events) do
      set_column_type(:exit_description, 'text')
    end
  end
end
