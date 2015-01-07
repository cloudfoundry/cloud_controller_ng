Sequel.migration do
  change do
    alter_table(:spaces) do
      add_column :space_quota_definition_id, Integer
      add_foreign_key [:space_quota_definition_id], :space_quota_definitions, name: :fk_space_sqd_id
    end
  end
end
