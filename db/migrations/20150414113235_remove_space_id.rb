Sequel.migration do
  # This migration was not backwards-compatible and caused API outages during upgrade.
  # It has been altered from its original form.

  up do
    alter_table :events do
      drop_foreign_key([:space_id])
    end
  end

  down do
    alter_table :events do
      add_foreign_key [:space_id], :spaces, name: :fk_no_cascade_events_space_id, on_delete: :set_null
    end
  end
end
