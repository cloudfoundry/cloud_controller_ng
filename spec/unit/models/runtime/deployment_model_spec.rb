require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DeploymentModel do
    let(:app) { AppModel.make(name: 'rolling-app') }
    let(:droplet) { DropletModel.make(app:) }
    let(:deploying_web_process) { ProcessModel.make(health_check_timeout: 180) }
    let(:canary_steps) { [{ 'instance_weight' => 20 }, { 'instance_weight' => 40 }] }
    let(:strategy) { DeploymentModel::CANARY_STRATEGY }
    let(:deployment) { DeploymentModel.make(app:, droplet:, deploying_web_process:, canary_steps:, strategy:) }

    it 'has an app' do
      expect(deployment.app.name).to eq('rolling-app')
    end

    it 'has a droplet' do
      expect(deployment.droplet).to eq(droplet)
    end

    it 'has a deploying web process' do
      expect(deployment.deploying_web_process).to eq(deploying_web_process)
    end

    it 'has canary steps' do
      expect(deployment.canary_steps).to eq(canary_steps)
    end

    describe '#before_create' do
      context 'when deployment is not a canary deployment' do
        let(:strategy) { DeploymentModel::ROLLING_STRATEGY }

        it 'does not set the canary_current_step' do
          expect(deployment.canary_current_step).to be_nil
        end
      end

      context 'when deployment is a canary deployment' do
        let(:strategy) { DeploymentModel::CANARY_STRATEGY }

        it 'sets the canary_current_step to 1' do
          expect(deployment.canary_current_step).to eq(1)
        end

        context 'when the canary steps instance weight keys are symbols' do
          let(:canary_steps) { [{ instance_weight: 20 }, { instance_weight: 40 }] }

          it 'converts the keys to strings' do
            expect(deployment.canary_steps).to eq([{ 'instance_weight' => 20 }, { 'instance_weight' => 40 }])
          end
        end
      end
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

    describe 'PROGRESSING_STATES' do
      it 'contains progressing forward states' do
        expect(DeploymentModel::PROGRESSING_STATES).to include(
          DeploymentModel::DEPLOYING_STATE,
          DeploymentModel::PAUSED_STATE,
          DeploymentModel::PREPAUSED_STATE
        )
      end
    end

    describe 'ACTIVE_STATES' do
      it 'contains active states' do
        expect(DeploymentModel::ACTIVE_STATES).to include(
          DeploymentModel::DEPLOYING_STATE,
          DeploymentModel::PAUSED_STATE,
          DeploymentModel::PREPAUSED_STATE,
          DeploymentModel::CANCELING_STATE
        )
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

    describe '#canary_step_plan' do
      tests = [
        {
          existing_instances: 10,
          weights: [20, 40],
          expected: [
            { canary: 2, original: 9 },
            { canary: 4, original: 7 }
          ]
        },
        {
          existing_instances: 10,
          weights: [80],
          expected: [
            { canary: 8, original: 3 }
          ]
        },
        {
          existing_instances: 5,
          weights: [20, 40],
          expected: [
            { canary: 1, original: 5 },
            { canary: 2, original: 4 }
          ]
        },
        {
          existing_instances: 10,
          weights: [20, 20, 20, 20],
          expected: [
            { canary: 2, original: 9 },
            { canary: 2, original: 9 },
            { canary: 2, original: 9 },
            { canary: 2, original: 9 }
          ]
        },
        {
          existing_instances: 3,
          weights: [1],
          expected: [
            { canary: 1, original: 3 }
          ]
        },
        {
          existing_instances: 1,
          weights: [1, 20, 40, 80, 100],
          expected: [
            { canary: 1, original: 1 },
            { canary: 1, original: 1 },
            { canary: 1, original: 1 },
            { canary: 1, original: 1 },
            { canary: 1, original: 0 }
          ]
        }
      ]

      tests.each do |test|
        context "with #{test[:existing_instances]} existing instances and weights #{test[:weights]}" do
          let(:canary_steps) { test[:weights].map { |weight| { instance_weight: weight } } }

          let(:deployment) do
            DeploymentModel.make(
              app: app,
              droplet: droplet,
              strategy: 'canary',
              deploying_web_process: deploying_web_process,
              original_web_process_instance_count: test[:existing_instances],
              canary_steps: canary_steps,
              canary_current_step: 1
            )
          end

          it 'returns the correct deployment plan' do
            expect(deployment.canary_step_plan).to eq(test[:expected])
          end
        end
      end

      context 'when deployment is canary but canary steps are empty' do
        let(:deployment) do
          DeploymentModel.make(
            app: app,
            strategy: 'canary',
            droplet: droplet,
            deploying_web_process: deploying_web_process,
            original_web_process_instance_count: 10,
            canary_current_step: 1
          )
        end

        it 'returns the correct deployment plan' do
          expect(deployment.canary_step_plan).to eq([{ canary: 1, original: 10 }])
        end
      end

      context 'when deployment is has a 100% step' do
        let(:deployment) do
          DeploymentModel.make(
            app: app,
            strategy: 'canary',
            droplet: droplet,
            deploying_web_process: deploying_web_process,
            canary_steps: [{ instance_weight: 1 }, { instance_weight: 25 }, { instance_weight: 50 }, { instance_weight: 99 }, { instance_weight: 100 }],
            original_web_process_instance_count: 10,
            canary_current_step: 1
          )
        end

        it 'provides an extra canary instance for every step except at 100%' do
          expect(deployment.canary_step_plan).to eq([{ canary: 1, original: 10 }, { canary: 3, original: 8 }, { canary: 5, original: 6 }, { canary: 10, original: 1 },
                                                     { canary: 10, original: 0 }])
        end
      end

      context 'when deployment is not canary' do
        let(:deployment) do
          DeploymentModel.make(
            app: app,
            strategy: 'rolling',
            droplet: droplet,
            deploying_web_process: deploying_web_process,
            original_web_process_instance_count: 10
          )
        end

        it 'returns the correct deployment plan' do
          expect { deployment.canary_step_plan }.to raise_error('canary_step_plan is only valid for canary deloyments')
        end
      end
    end

    describe '#current_canary_instance_target' do
      let(:deployment) do
        DeploymentModel.make(
          app: app,
          strategy: 'canary',
          droplet: droplet,
          deploying_web_process: deploying_web_process,
          canary_steps: [{ instance_weight: 1 }, { instance_weight: 25 }, { instance_weight: 50 }, { instance_weight: 99 }, { instance_weight: 100 }],
          original_web_process_instance_count: 10
        )
      end

      it 'returns the canary target of the current step' do
        deployment.update(canary_current_step: 3)

        expect(deployment.current_canary_instance_target).to eq(5)
      end
    end

    describe '#canary_total_instances' do
      let(:deployment) do
        DeploymentModel.make(
          app: app,
          strategy: 'canary',
          droplet: droplet,
          deploying_web_process: deploying_web_process,
          canary_steps: [{ instance_weight: 1 }, { instance_weight: 25 }, { instance_weight: 50 }, { instance_weight: 99 }, { instance_weight: 100 }],
          original_web_process_instance_count: 10
        )
      end

      it 'returns the total instances of the canary and original processes' do
        deployment.update(canary_current_step: 3)

        expect(deployment.canary_total_instances).to eq(11)
      end
    end

    describe '#canary_step' do
      let(:deployment) do
        DeploymentModel.make(
          app: app,
          strategy: 'canary',
          droplet: droplet,
          deploying_web_process: deploying_web_process,
          original_web_process_instance_count: 10,
          canary_steps: [{ instance_weight: 20 }, { instance_weight: 40 }],
          canary_current_step: 1
        )
      end

      it 'returns the correct deployment plan' do
        deployment.canary_current_step = 1
        expect(deployment.canary_step).to eq({ canary: 2, original: 9 })
        deployment.canary_current_step = 2
        expect(deployment.canary_step).to eq({ canary: 4, original: 7 })
      end

      context 'when canary current step is not set' do
        let(:deployment) do
          DeploymentModel.make(
            app: app,
            droplet: droplet,
            strategy: 'canary',
            deploying_web_process: deploying_web_process,
            original_web_process_instance_count: 10
          )
        end

        it 'returns the correct deployment plan' do
          expect(deployment.canary_step).to eq({ canary: 1, original: 10 })
        end
      end

      context 'when deployment is not canary' do
        let(:deployment) do
          DeploymentModel.make(
            app: app,
            strategy: 'rolling',
            droplet: droplet,
            deploying_web_process: deploying_web_process,
            original_web_process_instance_count: 10
          )
        end

        it 'returns the correct deployment plan' do
          expect { deployment.canary_step }.to raise_error('canary_step is only valid for canary deloyments')
        end
      end
    end
  end
end
