Sequel.migration do
  up do
    case_insensitive_columns = {
      domains: [:name],
      apps_v3: [:name],
      apps: [:name],
      organizations: [:name],
      quota_definitions: [:name],
      routes: [:host, :path],
      service_auth_tokens: [:label, :provider],
      service_plans: [:name],
      services: [:label, :provider],
      spaces: [:name]
    }
    ds = dataset.db.send(:metadata_dataset)
    statements = []
    if self.class.name.match /mysql/i
      tables.each do |table|
        columns_to_change = ds.with_sql("SHOW FULL COLUMNS FROM `#{table}`").to_a.select do |column_definition|
          next if case_insensitive_columns[table] && case_insensitive_columns[table].include?(column_definition[:Field].to_sym)
          column_definition[:Collation] == 'utf8_general_ci'
        end
        unless columns_to_change.empty?
          modify_column_strings = columns_to_change.collect do |column_definition|
            null_string = column_definition[:Null] == 'NO' ? 'NOT NULL' : 'NULL'
            default_string = column_definition[:Default] ? "DEFAULT '#{column_definition[:Default]}'" : ''
            "MODIFY `#{column_definition[:Field]}` #{column_definition[:Type]} COLLATE utf8_bin #{null_string} #{default_string}"
          end
          statements << "ALTER TABLE `#{table}` #{modify_column_strings.join(', ')};"
        end
      end
    end

    alter_table(:v3_droplets) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:packages) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:apps) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:apps_v3_routes) do
      drop_foreign_key [:app_v3_id]
    end

    statements.each { |s| run s }

    alter_table(:apps_v3_routes) do
      add_foreign_key [:app_v3_id], :apps_v3
    end

    alter_table(:apps) do
      add_foreign_key [:app_guid], :apps_v3, key: :guid
    end

    alter_table(:packages) do
      add_foreign_key [:app_guid], :apps_v3, key: :guid
    end
    alter_table(:v3_droplets) do
      add_foreign_key [:app_guid], :apps_v3, key: :guid
    end
  end
end
