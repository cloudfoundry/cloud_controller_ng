Sequel.migration do
  up do
    self[:apps_v3].truncate
    alter_table(:apps_v3) do
      add_column :name, String
      add_index :name
      add_index [:space_guid, :name], unique: true
      set_column_type :name, String, case_insensitive: true
    end
    if self.class.name.match /mysql/i
      table_name = tables.find { |t| t =~ /apps_v3/ }
      run "ALTER TABLE `#{table_name}` CONVERT TO CHARACTER SET utf8;"
    end
  end

  down do
    alter_table(:apps_v3) do
      drop_index [:space_guid, :name]
      drop_index :name
      drop_column :name
    end
  end
end
