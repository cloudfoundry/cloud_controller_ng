Sequel.migration do
  up do
    alter_table :events do
      drop_foreign_key([:space_id])
      drop_column :space_id
    end
  end

  down do
    alter_table :events do
      add_column :space_id, Integer, null: true
      add_foreign_key [:space_id], :spaces, name: :fk_no_cascade_events_space_id, on_delete: :set_null
    end
  end
end
