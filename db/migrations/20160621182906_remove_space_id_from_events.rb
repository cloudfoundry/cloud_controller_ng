Sequel.migration do
  up do
    alter_table :events do
      drop_column :space_id
    end
  end

  down do
    alter_table :events do
      add_column :space_id, Integer
    end
  end
end
