Sequel.migration do
  DEFAULT_TOTAL_ROUTES = 1000.freeze

  up do
    add_column :quota_definitions, :total_routes, :integer, null: true
    run("UPDATE quota_definitions SET total_routes = #{DEFAULT_TOTAL_ROUTES}")

    alter_table :quota_definitions do
      set_column_not_null :total_routes
    end
  end

  down do
    drop_column :quota_definitions, :total_routes
  end
end
