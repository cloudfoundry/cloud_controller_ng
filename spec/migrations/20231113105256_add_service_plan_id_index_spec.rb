require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add the service_plan_id index', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20231113105256_add_service_plan_id_index.rb' }
  end

  # The migration body is a no-op on MySQL, so only exercise it on PostgreSQL.
  it 'adds and removes the index' do
    skip if db.database_type != :postgres

    expect(db.indexes(:service_plan_visibilities)).not_to include(:spv_service_plan_id_index)

    expect { run_migration }.not_to raise_error
    expect(db.indexes(:service_plan_visibilities)).to include(:spv_service_plan_id_index)

    expect { revert_migration }.not_to raise_error
    expect(db.indexes(:service_plan_visibilities)).not_to include(:spv_service_plan_id_index)
  end
end
