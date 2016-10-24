Sequel.migration do
  change do
    create_table :organizations_private_stacks do
      Integer :organization_id, null: false
      foreign_key [:organization_id], :organizations, name: :fk_organization_id

      Integer :private_stack_id, null: false
      foreign_key [:private_stack_id], :stacks, name: :fk_private_stack_id

      index [:organization_id, :private_stack_id], unique: true, name: 'orgs_ps_ids'
    end

    create_table :spaces_private_stacks do
      Integer :space_id, null: false
      foreign_key [:space_id], :spaces, name: :fk_space_id

      Integer :private_stack_id, null: false
      foreign_key [:private_stack_id], :stacks, name: :fk_private_stack_id

      index [:space_id, :private_stack_id], unique: true, name: 'spaces_ps_ids'
    end

    alter_table :stacks do
      add_column :is_private, FalseClass
    end
  end
end
