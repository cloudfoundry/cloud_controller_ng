Sequel.migration do
  up do
    run("insert into organizations_users select * from organizations_managers m where NOT EXISTS (select * from organizations_users u where u.user_id = m.user_id and u.organization_id = m.organization_id)")
    run("insert into organizations_users select * from organizations_billing_managers m where NOT EXISTS (select * from organizations_users u where u.user_id = m.user_id and u.organization_id = m.organization_id)")
    run("insert into organizations_users select * from organizations_auditors m where NOT EXISTS (select * from organizations_users u where u.user_id = m.user_id and u.organization_id = m.organization_id)")
  end
end
