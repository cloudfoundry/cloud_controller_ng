Sequel.migration do
  up do
    add_index :events, :space_guid
    add_index :events, :organization_guid
  end

  down do
    drop_index :events, :space_guid
    drop_index :events, :organization_guid
  end
end
