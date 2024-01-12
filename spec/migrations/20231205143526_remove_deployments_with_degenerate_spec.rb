require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to clean up degenerate records from deployments records', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20231205143526_remove_deployments_with_degenerate.rb' }
  end

  describe 'deployments table' do
    it 'degenerate record is removed from deployments' do
      db[:deployments].insert(guid: 'deployed_guid', original_web_process_instance_count: 1, status_reason: 'DEPLOYED')
      db[:deployment_processes].insert(guid: 'deployed_process_guid', deployment_guid: 'deployed_guid')
      db[:deployment_annotations].insert(guid: 'deployed_annotation_guid', resource_guid: 'deployed_guid')
      db[:deployment_labels].insert(guid: 'deployed_label_guid', resource_guid: 'deployed_guid')

      db[:deployments].insert(guid: 'degenerate_guid', original_web_process_instance_count: 1, status_reason: 'DEGENERATE')
      db[:deployment_processes].insert(guid: 'degenerate_process_guid', deployment_guid: 'degenerate_guid')
      db[:deployment_annotations].insert(guid: 'degenerate_annotation_guid', resource_guid: 'degenerate_guid')
      db[:deployment_labels].insert(guid: 'degenerate_label_guid', resource_guid: 'degenerate_guid')

      expect { db[:deployments].where(guid: 'degenerate_guid').delete }.to raise_error(Sequel::ForeignKeyConstraintViolation)

      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error

      expect(db[:deployments].where(status_reason: 'DEGENERATE').count).to eq(0)

      expect(db[:deployments].first(guid: 'degenerate_guid')).to be_nil
      expect(db[:deployment_processes].first(guid: 'degenerate_process_guid')).to be_nil
      expect(db[:deployment_annotations].first(guid: 'degenerate_annotation_guid')).to be_nil
      expect(db[:deployment_labels].first(guid: 'degenerate_label_guid')).to be_nil

      expect(db[:deployments].first(guid: 'deployed_guid')).not_to be_nil
      expect(db[:deployment_processes].first(guid: 'deployed_process_guid')).not_to be_nil
      expect(db[:deployment_annotations].first(guid: 'deployed_annotation_guid')).not_to be_nil
      expect(db[:deployment_labels].first(guid: 'deployed_label_guid')).not_to be_nil
    end
  end
end
