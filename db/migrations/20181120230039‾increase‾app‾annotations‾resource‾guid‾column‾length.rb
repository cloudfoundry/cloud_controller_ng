Sequel.migration do
  change do
    alter_table :app_annotations do
      set_column_type :resource_guid, String, size: 255
    end
  end
end
