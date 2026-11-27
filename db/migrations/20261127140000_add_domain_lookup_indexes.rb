Sequel.migration do
  no_transaction # to create and drop indexes concurrently

  up do
    # MySQL already indexes these foreign key columns.
    next unless database_type == :postgres

    VCAP::Migration.with_concurrent_timeout(self) do
      add_index :domains, :owning_organization_id, name: :domains_owning_org_id_index, if_not_exists: true, concurrently: true
      add_index :organizations_private_domains, %i[private_domain_id organization_id],
                name: :orgs_pd_domain_org_ids, if_not_exists: true, concurrently: true
    end
  end

  down do
    next unless database_type == :postgres

    VCAP::Migration.with_concurrent_timeout(self) do
      drop_index :domains, nil, name: :domains_owning_org_id_index, if_exists: true, concurrently: true
      drop_index :organizations_private_domains, nil, name: :orgs_pd_domain_org_ids, if_exists: true, concurrently: true
    end
  end
end
