require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DeploymentModel do
    let(:app) { AppModel.make(name: 'rolling-app') }
    let(:droplet) { DropletModel.make(app: app) }
    let(:deploying_web_process) { ProcessModel.make(health_check_timeout: 180) }

    let(:deployment) { DeploymentModel.make(app: app, droplet: droplet, deploying_web_process: deploying_web_process) }

    it 'has an app' do
      expect(deployment.app.name).to eq('rolling-app')
    end

    it 'has a droplet' do
      expect(deployment.droplet).to eq(droplet)
    end

    it 'has a deploying web process' do
      expect(deployment.deploying_web_process).to eq(deploying_web_process)
    end

    context '#processes' do
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
    #
    # describe '#failing?' do
    #   it 'returns true if the deployment is failing' do
    #     deployment.state = 'FAILING'

    #     expect(deployment.failing?).to be(true)
    #   end
    # end

    describe '#should_fail?' do
      let(:deployment) { DeploymentModel.make(app: app,
                                              droplet: droplet,
                                              state: state,
                                              deploying_web_process: deploying_web_process,
                                              last_healthy_at: last_healthy_at)
      }
      let(:last_healthy_at) { Time.now }
      let(:state) { DeploymentModel::DEPLOYING_STATE }

      it 'returns false if last_healthy_at is nil' do
        expect(deployment.should_fail?).to eq false
      end

      context 'when last_healthy_at is more recent than 2x the processes timeout ago' do
        let(:last_healthy_at) { 359.seconds.ago }

        it 'returns false' do
          expect(deployment.should_fail?).to eq false
        end
      end

      context 'when last_healthy_at is longer than 2x the processes timeout ago' do
        let(:last_healthy_at) { 361.seconds.ago }

        it 'returns true' do
          expect(deployment.should_fail?).to eq true
        end

        context 'when the deployment is not deploying' do
          let(:state) { DeploymentModel::DEPLOYED_STATE }

          it 'returns false' do
            expect(deployment.should_fail?).to eq false
          end
        end
      end

      context 'when last_healthy_at is 2x the processes timeout ago' do
        let(:last_healthy_at) { 360.seconds.ago }

        it 'returns true' do
          expect(deployment.should_fail?).to eq true
        end

        context 'when the deployment is not deploying' do
          let(:state) { DeploymentModel::DEPLOYED_STATE }

          it 'returns false' do
            expect(deployment.should_fail?).to eq false
          end
        end
      end
    end
  end
end
