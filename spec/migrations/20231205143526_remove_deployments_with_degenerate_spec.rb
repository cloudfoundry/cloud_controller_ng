require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to clean up degenerate records from deployments records', isolation: :truncation do
  include_context 'migration' do
    let(:migration_filename) { '20231205143526_remove_deployments_with_degenerate.rb' }
  end

  describe 'deployments table' do
    it 'degenerate record is removed from deployments' do
      db[:deployments].insert(
        guid: 'bommel',
        original_web_process_instance_count: 1,
        status_reason: 'DEGENERATE'
      )

      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error
      deployment = db[:deployments].first(status_reason: 'DEGENERATE')
      expect(deployment).to be_nil
    end
  end
end
