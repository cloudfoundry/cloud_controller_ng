Sequel.migration do
    change do
       alter_table :apps do
        drop_foreign_key ([:space_id])
        set_column_allow_null(:space_id)
        add_foreign_key [:space_id], :spaces, :name => :fk_apps_space_id,:on_delete => :set_null
   
        drop_foreign_key ([:stack_id])
        set_column_allow_null(:stack_id)
        add_foreign_key [:stack_id], :stacks, :name => :fk_apps_stack_id, :on_delete => :set_null
      end
    end
  end
