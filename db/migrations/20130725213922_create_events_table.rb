Sequel.migration do
  change do
    create_table :events do
      VCAP::Migration.common(self)

      DateTime :timestamp, null: false
      String :type, null: false
      String :actor, null: false
      String :actor_type, null: false
      String :actee, null: false
      String :actee_type, null: false
      String :metadata, null: false, default: '{}'

      Integer :space_id, null: false

      foreign_key [:space_id], :spaces, name: :fk_events_space_id
    end
  end
end
