Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column :salt, String
      add_column :secure_token, String
    end

    run 'ALTER TABLE `tasks` CHANGE COLUMN `secure_token` `secure_token` TEXT' if self.class.name.match?(/mysql/i)
  end
end
