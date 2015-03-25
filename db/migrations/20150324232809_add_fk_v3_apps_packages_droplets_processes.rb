Sequel.migration do
  up do
    alter_table(:apps) do
      add_index :app_guid
      add_foreign_key [:app_guid], :apps_v3, key: :guid
    end

    if self.class.name.match(/mysql/i)
      ['packages', 'v3_droplets'].each do |table_name|
        run "ALTER TABLE `#{table_name}` CONVERT TO CHARACTER SET utf8;"
      end
    end

    alter_table(:packages) do
      add_foreign_key [:app_guid], :apps_v3, key: :guid
    end
    alter_table(:v3_droplets) do
      add_foreign_key [:app_guid], :apps_v3, key: :guid
    end
  end

  down do
    alter_table(:v3_droplets) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:packages) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:apps) do
      drop_foreign_key [:app_guid]
      drop_index :app_guid
    end
  end
end
