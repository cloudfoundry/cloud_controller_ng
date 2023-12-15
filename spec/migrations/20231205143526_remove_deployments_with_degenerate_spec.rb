require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to clean up degenerate records from deployments records', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20231205143526_remove_deployments_with_degenerate.rb'),
      tmp_migrations_dir
    )
  end

  let(:app) { VCAP::CloudController::AppModel.make }

  context 'when a table has status reason DEGENERATE' do
    let!(:deployment_with_status_reason_degenerate) do
      VCAP::CloudController::DeploymentModel.create(
        guid: 'with-status-reason-degenerate',
        app: app,
        original_web_process_instance_count: 1,
        status_reason: 'DEGENERATE'
      )
    end

    it 'degenerate record is removed from deployments' do
      Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
      deployment = VCAP::CloudController::DeploymentModel.where(status_reason: 'DEGENERATE').first

      expect(deployment).to be_nil
    end
  end
end
