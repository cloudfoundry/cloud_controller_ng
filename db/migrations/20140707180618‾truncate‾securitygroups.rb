Sequel.migration do
  change do
    alter_table(:security_groups_spaces) do
      drop_foreign_key [:security_group_id], name: :fk_security_group_id
    end

    self[:security_groups_spaces].truncate
    self[:security_groups].truncate

    alter_table(:security_groups_spaces) do
      add_foreign_key [:security_group_id], :security_groups, name: :fk_security_group_id
    end
  end
end
