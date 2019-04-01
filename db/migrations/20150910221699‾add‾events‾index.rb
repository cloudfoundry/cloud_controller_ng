Sequel.migration do
  up do
    self[:events].truncate

    add_index :events, :actee_type
    add_index :events, [:timestamp, :id]
    drop_index :events, :timestamp
  end

  down do
    add_index :events, :timestamp
    drop_index :events, [:timestamp, :id]
    drop_index :events, :actee_type
  end
end
