Sequel.migration do
  up do
    alter_table :events do
      # BEFORE
      #
      # Previously `space_id` could not be null, and if a space was deleted its
      # related events were cascaded deleted along with it.

      # AFTER
      #
      # If the related space is deleted the `space_id` becomes `null`. We need
      # to maintain the `space_id` for non-deleted spaces so that we can use
      # the related space for access control. After this migration is applied
      # if the space is deleted, the event remains (for audit purposes) but can
      # only be seen by admins.
      drop_foreign_key([:space_id])
      set_column_allow_null(:space_id)
      add_foreign_key [:space_id], :spaces, name: :fk_no_cascade_events_space_id, on_delete: :set_null

      # Store these columns in denormalized form so they survive deletions of
      # the respective relations.
      add_column :organization_guid, String, null: false, default: ''
      add_column :space_guid, String, null: false, default: ''
    end
  end

  down do
    alter_table :events do
      # Even after the down migration the new foreign key (without the CASCADE
      # DELETE, and without the non-null constraint) will be present. This is
      # because we can't really reverse the allowing of nulls (if nulls were
      # added we wouldn't be able to set allow_null back to false).
      drop_column :space_guid
      drop_column :organization_guid
    end
  end
end
