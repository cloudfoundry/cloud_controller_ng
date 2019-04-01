Sequel.migration do
  up do
    self[:events].truncate

    alter_table(:events) do
      add_index :actee, name: 'events_actee_index'
    end
  end

  down do
    alter_table(:events) do
      drop_index :actee, name: 'events_actee_index'
    end
  end
end
