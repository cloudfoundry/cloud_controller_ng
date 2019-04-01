# This migration was not backwards-compatible and caused API outages during upgrade.
# It has been altered from its original form.

Sequel.migration do
  up do
    alter_table :routes do
      drop_foreign_key [:service_instance_id]
    end
  end

  down do
    alter_table :routes do
      add_foreign_key [:service_instance_id], :service_instances
    end
  end
end
