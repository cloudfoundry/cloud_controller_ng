Sequel.migration do
  up do
    add_column :apps, :health_check_type, String, default: 'port'

    run <<-SQL
      UPDATE apps a1
      SET health_check_type = 'none'
      WHERE id NOT IN (
        SELECT id FROM (
          SELECT id
          FROM   apps a2
                 LEFT JOIN apps_routes
                        ON apps_routes.app_id = a2.id
          GROUP  BY 1
        ) t2
      )
    SQL
  end

  down do
    drop_column :apps, :health_check_type
  end
end
