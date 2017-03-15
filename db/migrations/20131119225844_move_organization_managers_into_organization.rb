Sequel.migration do
  up do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
        INSERT INTO ORGANIZATIONS_USERS SELECT * FROM ORGANIZATIONS_MANAGERS m
        WHERE NOT EXISTS (SELECT * FROM ORGANIZATIONS_USERS u WHERE u.USER_ID = m.USER_ID AND u.ORGANIZATION_ID = m.ORGANIZATION_ID)
      SQL

      run <<-SQL
        INSERT INTO ORGANIZATIONS_USERS SELECT * FROM ORGANIZATIONS_BILLING_MANAGERS m
        WHERE NOT EXISTS (SELECT * FROM ORGANIZATIONS_USERS u WHERE u.USER_ID = m.USER_ID AND u.ORGANIZATION_ID = m.ORGANIZATION_ID)
      SQL

      run <<-SQL
        INSERT INTO ORGANIZATIONS_USERS SELECT * FROM ORGANIZATIONS_AUDITORS m
        WHERE NOT EXISTS (SELECT * FROM ORGANIZATIONS_USERS u WHERE u.USER_ID = m.USER_ID AND u.ORGANIZATION_ID = m.ORGANIZATION_ID)
      SQL
    else
      run <<-SQL
        INSERT INTO organizations_users SELECT * FROM organizations_managers m
        WHERE NOT EXISTS (SELECT * FROM organizations_users u WHERE u.user_id = m.user_id AND u.organization_id = m.organization_id)
      SQL

      run <<-SQL
        INSERT INTO organizations_users SELECT * FROM organizations_billing_managers m
        WHERE NOT EXISTS (SELECT * FROM organizations_users u WHERE u.user_id = m.user_id AND u.organization_id = m.organization_id)
      SQL

      run <<-SQL
        INSERT INTO organizations_users SELECT * FROM organizations_auditors m
        WHERE NOT EXISTS (SELECT * FROM organizations_users u WHERE u.user_id = m.user_id AND u.organization_id = m.organization_id)
      SQL
    end
  end
end
