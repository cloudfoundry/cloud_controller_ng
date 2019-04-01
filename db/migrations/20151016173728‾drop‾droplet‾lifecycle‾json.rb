Sequel.migration do
  up do
    alter_table(:v3_droplets) do
      drop_column :lifecycle
    end
  end

  down do
    add_column :v3_droplets, :lifecycle, String, text: true, null: true
  end
end
