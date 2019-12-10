require 'spec_helper'

RSpec.describe 'backfill status_value for deployments', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20190712210940_backfill_status_for_deployments.rb'),
      tmp_migrations_dir,
    )
  end

  let(:app) { VCAP::CloudController::AppModel.make }

  context 'when a deployment has state DEPLOYED' do
    let!(:deployment_with_state_deployed) do
      VCAP::CloudController::DeploymentModel.create(
        guid: 'with-state-deployed',
        state: VCAP::CloudController::DeploymentModel::DEPLOYED_STATE,
        app: app,
        original_web_process_instance_count: 1
      )
    end

    it 'sets status_value to FINALIZED without changing the state' do
      Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
      deployment = VCAP::CloudController::DeploymentModel.where(guid: deployment_with_state_deployed.guid).first

      expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::DEPLOYED_STATE)
      expect(deployment.status_value).to eq(VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE)
      expect(deployment.status_reason).to be_nil
    end
  end

  context 'when a deployment has state CANCELED' do
    let!(:deployment_with_state_canceled) do
      VCAP::CloudController::DeploymentModel.create(
        guid: 'with-state-canceled',
        state: VCAP::CloudController::DeploymentModel::CANCELED_STATE,
        app: app,
        original_web_process_instance_count: 1
      )
    end

    it 'sets status_value to FINALIZED without changing the state' do
      Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
      deployment = VCAP::CloudController::DeploymentModel.where(guid: deployment_with_state_canceled.guid).first

      expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::CANCELED_STATE)
      expect(deployment.status_value).to eq(VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE)
      expect(deployment.status_reason).to be_nil
    end
  end

  context 'when a deployment has state FAILED' do
    let!(:deployment_with_state_failed) do
      VCAP::CloudController::DeploymentModel.create(
        guid: 'with-state-failed',
        state: 'FAILED',
        app: app,
        original_web_process_instance_count: 1
      )
    end

    it 'sets status_value to FINALIZED without changing the state' do
      Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
      deployment = VCAP::CloudController::DeploymentModel.where(guid: deployment_with_state_failed.guid).first

      expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::DEPLOYED_STATE)
      expect(deployment.status_value).to eq(VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE)
      expect(deployment.status_reason).to be_nil
    end
  end

  context 'when a deployment has state DEPLOYING' do
    let!(:deployment_with_state_deploying) do
      VCAP::CloudController::DeploymentModel.create(
        guid: 'with-state-deploying',
        state: VCAP::CloudController::DeploymentModel::DEPLOYING_STATE,
        app: app,
        original_web_process_instance_count: 1
      )
    end

    it 'sets status_value to DEPLOYING without changing the state' do
      Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
      deployment = VCAP::CloudController::DeploymentModel.where(guid: deployment_with_state_deploying.guid).first

      expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
      expect(deployment.status_value).to eq('DEPLOYING')
      expect(deployment.status_reason).to be_nil
    end
  end

  context 'when a deployment has state CANCELING' do
    let!(:deployment_with_state_canceling) do
      VCAP::CloudController::DeploymentModel.create(
        guid: 'with-state-canceling',
        state: VCAP::CloudController::DeploymentModel::CANCELING_STATE,
        app: app,
        original_web_process_instance_count: 1
      )
    end

    it 'sets status_value to DEPLOYING without changing the state' do
      Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
      deployment = VCAP::CloudController::DeploymentModel.where(guid: deployment_with_state_canceling.guid).first

      expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::CANCELING_STATE)
      expect(deployment.status_value).to eq('DEPLOYING')
      expect(deployment.status_reason).to be_nil
    end
  end

  context 'when a deployment has state FAILING' do
    let!(:deployment_with_state_failing) do
      VCAP::CloudController::DeploymentModel.create(
        guid: 'with-state-failing',
        state: 'FAILING',
        app: app,
        original_web_process_instance_count: 1
      )
    end

    it 'sets status_value to DEPLOYING without changing the state' do
      Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
      deployment = VCAP::CloudController::DeploymentModel.where(guid: deployment_with_state_failing.guid).first

      expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
      expect(deployment.status_value).to eq('DEPLOYING')
      expect(deployment.status_reason).to be_nil
    end
  end

  context 'when the deployment already has a status' do
    context 'when the deployment has state DEPLOYED' do
      let!(:deployment_with_state_deployed) do
        VCAP::CloudController::DeploymentModel.create(
          guid: 'with-state-deployed',
          state: VCAP::CloudController::DeploymentModel::DEPLOYED_STATE,
          status_value: 'foo',
          status_reason: 'bar',
          app: app,
          original_web_process_instance_count: 1
        )
      end

      it 'does not reset the status value' do
        Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
        deployment = VCAP::CloudController::DeploymentModel.where(guid: deployment_with_state_deployed.guid).first

        expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::DEPLOYED_STATE)
        expect(deployment.status_value).to eq('foo')
        expect(deployment.status_reason).to eq('bar')
      end
    end

    context 'when the deployment has state FAILING' do
      let!(:deployment_with_state_failing) do
        VCAP::CloudController::DeploymentModel.create(
          guid: 'with-state-deployed',
          state: 'FAILING',
          status_value: 'foo',
          status_reason: 'bar',
          app: app,
          original_web_process_instance_count: 1
        )
      end

      it 'does not reset the status reason' do
        Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
        deployment = VCAP::CloudController::DeploymentModel.where(guid: deployment_with_state_failing.guid).first

        expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
        expect(deployment.status_value).to eq('DEPLOYING')
        expect(deployment.status_reason).to eq('bar')
      end
    end
  end
end
