Sequel.migration do
  up do
    add_index :events, [:timestamp, :id]
    drop_index :events, :timestamp
  end

  down do
    add_index :events, :timestamp
    drop_index :events, [:timestamp, :id]
  end
end
