Sequel.migration do
  up do
    run <<-SQL
      UPDATE apps
        SET ports = null
      WHERE docker_image is not null
        and diego = true
        and ports = '[8080]'
    SQL

    run <<-SQL
      UPDATE apps_routes
        SET app_port = null
      WHERE app_port = '8080'
        and app_id in (
          SELECT id from apps where diego = true
        )
    SQL
  end

  down do
    run <<-SQL
      UPDATE apps
        SET ports = '8080'
      WHERE ports is null and diego = true and docker_image is null
    SQL
  end
end
