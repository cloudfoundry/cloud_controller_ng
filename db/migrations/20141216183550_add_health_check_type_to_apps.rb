Sequel.migration do
  up do
    add_column :apps, :health_check_type, String, default: 'port'

    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
        UPDATE a1
        SET HEALTH_CHECK_TYPE = 'none'
        from APPS a1
        WHERE ID NOT IN (
          SELECT ID FROM (
            SELECT ID
            FROM APPS a2
                  LEFT JOIN APPS_ROUTES
                          ON APPS_ROUTES.APP_ID = a2.ID
            GROUP BY ID
          ) t2
        )
        SQL
    else
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
  end

  down do
    drop_column :apps, :health_check_type
  end
end
