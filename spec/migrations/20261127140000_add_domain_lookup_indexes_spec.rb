require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add domain lookup indexes', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20261127140000_add_domain_lookup_indexes.rb' }
  end

  it 'adds and removes non-unique indexes idempotently' do
    skip unless db.database_type == :postgres

    expect(db.indexes(:domains)).not_to include(:domains_owning_org_id_index)
    expect(db.indexes(:organizations_private_domains)).not_to include(:orgs_pd_domain_org_ids)

    expect { run_migration }.not_to raise_error
    expect(db.indexes(:domains)[:domains_owning_org_id_index]).to include(columns: [:owning_organization_id], unique: false)
    expect(db.indexes(:organizations_private_domains)[:orgs_pd_domain_org_ids]).to include(columns: %i[private_domain_id organization_id], unique: false)
    expect(db.indexes(:organizations_private_domains)[:orgs_pd_ids]).to include(columns: %i[organization_id private_domain_id], unique: true)

    test_up_migration_idempotency
    expect(db.indexes(:domains)[:domains_owning_org_id_index]).to include(columns: [:owning_organization_id], unique: false)
    expect(db.indexes(:organizations_private_domains)[:orgs_pd_domain_org_ids]).to include(columns: %i[private_domain_id organization_id], unique: false)
    expect(db.indexes(:organizations_private_domains)[:orgs_pd_ids]).to include(columns: %i[organization_id private_domain_id], unique: true)

    expect { revert_migration }.not_to raise_error
    expect(db.indexes(:domains)).not_to include(:domains_owning_org_id_index)
    expect(db.indexes(:organizations_private_domains)).not_to include(:orgs_pd_domain_org_ids)
    expect(db.indexes(:organizations_private_domains)[:orgs_pd_ids]).to include(columns: %i[organization_id private_domain_id], unique: true)

    test_down_migration_idempotency
    expect(db.indexes(:domains)).not_to include(:domains_owning_org_id_index)
    expect(db.indexes(:organizations_private_domains)).not_to include(:orgs_pd_domain_org_ids)
    expect(db.indexes(:organizations_private_domains)[:orgs_pd_ids]).to include(columns: %i[organization_id private_domain_id], unique: true)
  end
end
