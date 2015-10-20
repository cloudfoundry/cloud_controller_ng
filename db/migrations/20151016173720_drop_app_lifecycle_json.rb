Sequel.migration do
  up do
    drop_column :apps_v3, :lifecycle
  end

  down do
    alter_table(:app_v3) do
      add_column :lifecycle, String, text: true, null: true
    end
  end
end
