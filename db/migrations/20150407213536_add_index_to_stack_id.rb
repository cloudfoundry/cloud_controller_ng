Sequel.migration do
  up do
    add_index :apps, :stack_id
  end

  down do
    alter_table :apps do
      drop_foreign_key [:stack_id]
      drop_index :stack_id
      add_foreign_key [:stack_id], :stacks, name: :fk_apps_stack_id
    end
  end
end
