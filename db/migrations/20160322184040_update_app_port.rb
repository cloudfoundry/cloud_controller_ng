Sequel.migration do
  up do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
        UPDATE APPS
          SET PORTS = null
        WHERE DOCKER_IMAGE is not null
          and DIEGO = 1
          and PORTS = '[8080]'
      SQL
    else
      run <<-SQL
      UPDATE apps
        SET ports = null
      WHERE docker_image is not null
        and diego = true
        and ports = '[8080]'
      SQL
    end

    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
        UPDATE APPS_ROUTES
          SET APP_PORT = null
        WHERE APP_PORT = '8080'
          and APP_ID in (
            SELECT ID from APPS where DIEGO = 1
          )
      SQL
    else
      run <<-SQL
        UPDATE apps_routes
          SET app_port = null
        WHERE app_port = '8080'
          and app_id in (
            SELECT id from apps where diego = true
          )
      SQL
    end
  end

  down do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
        UPDATE APPS
          SET PORTS = '8080'
        WHERE PORTS is null and DIEGO = 1 and DOCKER_IMAGE is null
      SQL
    else
      run <<-SQL
        UPDATE apps
          SET ports = '8080'
        WHERE ports is null and diego = true and docker_image is null
      SQL
    end
  end
end
