Sequel.migration do
  up do
    alter_table :packages do
      drop_column :space_guid
    end
  end

  down do
    alter_table :packages do
      add_column :space_guid, String
      add_index :space_guid
    end
  end
end
