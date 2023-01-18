Sequel.migration do
  change do
    alter_table :jobs do
      set_column_type(:cf_api_error, 'text')
    end
  end
end
