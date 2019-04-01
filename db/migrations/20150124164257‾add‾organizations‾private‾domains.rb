Sequel.migration do
  change do
    create_table :organizations_private_domains do
      Integer :organization_id, null: false
      foreign_key [:organization_id], :organizations, name: :fk_organization_id

      Integer :private_domain_id, null: false
      foreign_key [:private_domain_id], :domains, name: :fk_private_domain_id

      index [:organization_id, :private_domain_id], unique: true, name: 'orgs_pd_ids'
    end
  end
end
