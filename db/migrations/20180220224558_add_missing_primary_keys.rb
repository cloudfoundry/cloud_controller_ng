Sequel.migration do
  change do
    alter_table :organizations_auditors do
      add_primary_key :id, name: :organizations_auditors_pk
    end

    alter_table :organizations_billing_managers do
      add_primary_key :id, name: :organizations_billing_managers_pk
    end

    alter_table :organizations_managers do
      add_primary_key :id, name: :organizations_managers_pk
    end

    alter_table :organizations_private_domains do
      add_primary_key :id, name: :organizations_private_domains_pk
    end

    alter_table :organizations_users do
      add_primary_key :id, name: :organizations_users_pk
    end

    alter_table :security_groups_spaces do
      add_primary_key :id, name: :security_groups_spaces_pk
    end

    alter_table :spaces_auditors do
      add_primary_key :id, name: :spaces_auditors_pk
    end

    alter_table :spaces_developers do
      add_primary_key :id, name: :spaces_developers_pk
    end

    alter_table :spaces_managers do
      add_primary_key :id, name: :spaces_managers_pk
    end

    alter_table :staging_security_groups_spaces do
      add_primary_key :id, name: :staging_security_groups_spaces_pk
    end
  end
end
