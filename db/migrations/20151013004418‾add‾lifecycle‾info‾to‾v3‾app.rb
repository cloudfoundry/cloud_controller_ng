Sequel.migration do
  up do
    add_column :apps_v3, :lifecycle, String, text: true, null: true
  end

  down do
    alter_table(:app_v3) do
      drop_column :lifecycle
    end
  end
end
