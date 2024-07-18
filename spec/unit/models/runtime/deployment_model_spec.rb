require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DeploymentModel do
    let(:app) { AppModel.make(name: 'rolling-app') }
    let(:droplet) { DropletModel.make(app:) }
    let(:deploying_web_process) { ProcessModel.make(health_check_timeout: 180) }

    let(:deployment) { DeploymentModel.make(app:, droplet:, deploying_web_process:) }

    it 'has an app' do
      expect(deployment.app.name).to eq('rolling-app')
    end

    it 'has a droplet' do
      expect(deployment.droplet).to eq(droplet)
    end

    it 'has a deploying web process' do
      expect(deployment.deploying_web_process).to eq(deploying_web_process)
    end

    describe '#processes' do
      before do
        DeploymentProcessModel.make(
          deployment: deployment,
          process_guid: deploying_web_process.guid,
          process_type: deploying_web_process.type
        )
        DeploymentProcessModel.make(
          deployment: deployment,
          process_guid: 'guid-for-deleted-process',
          process_type: 'i-do-not-exist!!!!!!!!!!'
        )
        DeploymentProcessModel.make(
          deployment: DeploymentModel.make
        )
      end

      it 'has deployment processes with the deploying web process' do
        expect(
          deployment.historical_related_processes.map(&:deployment_guid)
        ).to contain_exactly(deployment.guid, deployment.guid)

        expect(
          deployment.historical_related_processes.map(&:process_guid)
        ).to contain_exactly(deploying_web_process.guid, 'guid-for-deleted-process')

        expect(
          deployment.historical_related_processes.map(&:process_type)
        ).to contain_exactly(deploying_web_process.type, 'i-do-not-exist!!!!!!!!!!')
      end
    end

    describe '#deploying?' do
      it 'returns true if the deployment is deploying' do
        deployment.state = 'DEPLOYING'

        expect(deployment.deploying?).to be(true)
      end

      it 'returns true if the deployment is PAUSED' do
        deployment.state = DeploymentModel::PAUSED_STATE

        expect(deployment.deploying?).to be(true)
      end

      it 'returns true if the deployment is PREPAUSED' do
        deployment.state = DeploymentModel::PREPAUSED_STATE

        expect(deployment.deploying?).to be(true)
      end

      it 'returns false if the deployment has been deployed' do
        deployment.state = 'DEPLOYED'

        expect(deployment.deploying?).to be(false)
      end

      it 'returns false if the deployment is canceling' do
        deployment.state = 'CANCELING'

        expect(deployment.deploying?).to be(false)
      end

      it 'returns false if the deployment has been canceled' do
        deployment.state = 'CANCELED'

        expect(deployment.deploying?).to be(false)
      end
    end

    describe '#cancelable?' do
      it 'returns true if the deployment is DEPLOYING' do
        deployment.state = DeploymentModel::DEPLOYING_STATE

        expect(deployment.cancelable?).to be(true)
      end

      it 'returns true if the deployment is PAUSED' do
        deployment.state = DeploymentModel::PAUSED_STATE

        expect(deployment.cancelable?).to be(true)
      end

      it 'returns true if the deployment is PREPAUSED' do
        deployment.state = DeploymentModel::PREPAUSED_STATE

        expect(deployment.cancelable?).to be(true)
      end

      it 'returns false if the deployment is DEPLOYED' do
        deployment.state = DeploymentModel::DEPLOYED_STATE

        expect(deployment.cancelable?).to be(false)
      end

      it 'returns true if the deployment is CANCELING' do
        deployment.state = DeploymentModel::CANCELING_STATE

        expect(deployment.cancelable?).to be(true)
      end

      it 'returns false if the deployment is CANCELED' do
        deployment.state = DeploymentModel::CANCELED_STATE

        expect(deployment.cancelable?).to be(false)
      end
    end

    describe '#continuable?' do
      it 'returns true if the deployment is PAUSED' do
        deployment.state = DeploymentModel::PAUSED_STATE

        expect(deployment.continuable?).to be(true)
      end

      it 'returns false if the deployment is PREPAUSED' do
        deployment.state = DeploymentModel::PREPAUSED_STATE

        expect(deployment.continuable?).to be(false)
      end

      it 'returns false if the deployment is DEPLOYING state' do
        deployment.state = DeploymentModel::DEPLOYING_STATE

        expect(deployment.continuable?).to be(false)
      end

      it 'returns false if the deployment is DEPLOYED state' do
        deployment.state = DeploymentModel::DEPLOYED_STATE

        expect(deployment.continuable?).to be(false)
      end

      it 'returns true if the deployment is CANCELING' do
        deployment.state = DeploymentModel::CANCELING_STATE

        expect(deployment.continuable?).to be(false)
      end

      it 'returns false if the deployment is CANCELED' do
        deployment.state = DeploymentModel::CANCELED_STATE

        expect(deployment.continuable?).to be(false)
      end
    end

    describe '#status_updated_at' do
      let(:deployment) do
        DeploymentModel.make(
          app: app,
          droplet: droplet,
          deploying_web_process: deploying_web_process,
          status_reason: DeploymentModel::DEPLOYING_STATUS_REASON,
          status_value: DeploymentModel::ACTIVE_STATUS_VALUE
        )
      end

      # Can't use Timecop with created_at since its set by the DB
      let(:creation_time) { deployment.created_at }
      let(:update_time) { deployment.created_at + 24.hours }

      before do
        Timecop.freeze(creation_time)
      end

      after do
        Timecop.return
      end

      it 'is defaulted with the created_at time' do
        expect(deployment.status_updated_at).to eq(deployment.created_at)
      end

      it 'updates when status_reason has changed' do
        deployment.status_reason = DeploymentModel::CANCELING_STATUS_REASON
        Timecop.freeze(update_time)
        deployment.save
        expect(deployment.status_updated_at).to eq update_time
      end

      it 'updates when status_value has changed' do
        deployment.status_value = DeploymentModel::FINALIZED_STATUS_VALUE
        Timecop.freeze(update_time)
        deployment.save
        expect(deployment.status_updated_at).to eq update_time
      end

      it 'doesnt update when status_value or status_reason is unchanged' do
        deployment.strategy = 'faux_strategy'
        Timecop.freeze(update_time)
        deployment.save
        expect(deployment.status_updated_at).to eq creation_time
      end
    end
  end
end
