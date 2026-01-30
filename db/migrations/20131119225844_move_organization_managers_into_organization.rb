Sequel.migration do
  up do
    run <<~SQL.squish
      INSERT INTO organizations_users SELECT * FROM organizations_managers m
      WHERE NOT EXISTS (SELECT * FROM organizations_users u WHERE u.user_id = m.user_id AND u.organization_id = m.organization_id)
    SQL

    run <<~SQL.squish
      INSERT INTO organizations_users SELECT * FROM organizations_billing_managers m
      WHERE NOT EXISTS (SELECT * FROM organizations_users u WHERE u.user_id = m.user_id AND u.organization_id = m.organization_id)
    SQL

    run <<~SQL.squish
      INSERT INTO organizations_users SELECT * FROM organizations_auditors m
      WHERE NOT EXISTS (SELECT * FROM organizations_users u WHERE u.user_id = m.user_id AND u.organization_id = m.organization_id)
    SQL
  end
end
