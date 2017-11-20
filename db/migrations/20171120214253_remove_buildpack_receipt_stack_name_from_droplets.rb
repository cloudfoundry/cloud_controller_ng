Sequel.migration do
  up do
    alter_table :droplets do
      drop_column :buildpack_receipt_stack_name
    end
  end

  down do
    alter_table :droplets do
      add_column :buildpack_receipt_stack_name, String
    end
  end
end
