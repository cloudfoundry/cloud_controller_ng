require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PruneCompletedDeployments, job_context: :worker do
      let(:max_retained_deployments_per_app) { 15 }
      subject(:job) { PruneCompletedDeployments.new(max_retained_deployments_per_app) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:prune_completed_deployments)
      end

      describe '#perform' do
        let(:app) { AppModel.make(name: 'app') }

        it 'deletes all the deployed deployments over the limit' do
          expect(DeploymentModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            DeploymentModel.make(id: i, state: DeploymentModel::DEPLOYED_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(DeploymentModel.count).to eq(15)
          expect(DeploymentModel.map(&:id)).to match_array((36..50).to_a)
        end

        it 'deletes all canceled deployments over the limit' do
          expect(DeploymentModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            DeploymentModel.make(id: i, state: DeploymentModel::CANCELED_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(DeploymentModel.count).to eq(15)
          expect(DeploymentModel.map(&:id)).to match_array((36..50).to_a)
        end

        it 'does NOT delete any deploying deployments over the limit' do
          expect(DeploymentModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            DeploymentModel.make(id: i, state: DeploymentModel::DEPLOYING_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(DeploymentModel.count).to eq(50)
          expect(DeploymentModel.map(&:id)).to match_array((1..50).to_a)
        end

        it 'does NOT delete any canceling deployments over the limit' do
          expect(DeploymentModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            DeploymentModel.make(id: i, state: DeploymentModel::CANCELING_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(DeploymentModel.count).to eq(50)
          expect(DeploymentModel.order(Sequel.asc(:created_at)).map(&:id)).to eq((1..50).to_a)
        end

        it 'does not delete in-flight deployments over the limit' do
          total = 60
          (1..20).each do |i|
            DeploymentModel.make(id: i, state: DeploymentModel::DEPLOYED_STATE, app: app, created_at: Time.now - total + i)
          end
          (21..40).each do |i|
            DeploymentModel.make(id: i, state: DeploymentModel::DEPLOYING_STATE, app: app, created_at: Time.now - total + i)
          end
          (41..60).each do |i|
            DeploymentModel.make(id: i, state: DeploymentModel::DEPLOYED_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(DeploymentModel.count).to be(35)
          expect(DeploymentModel.order(Sequel.asc(:created_at)).map(&:id)).to eq((21..40).to_a + (46..60).to_a)
        end

        it 'destroys metadata associated with pruned deployments' do
          expect(DeploymentModel.count).to eq(0)
          expect(DeploymentLabelModel.count).to eq(0)
          expect(DeploymentAnnotationModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            deployment = DeploymentModel.make(id: i, state: DeploymentModel::DEPLOYED_STATE, app: app, created_at: Time.now - total + i)
            DeploymentAnnotationModel.make(deployment: deployment, key: i, value: i)
            DeploymentLabelModel.make(deployment: deployment, key_name: i, value: i)
          end

          job.perform

          expect(DeploymentModel.count).to eq(15)
          expect(DeploymentModel.map(&:id)).to match_array((36..50).to_a)
          expect(DeploymentLabelModel.count).to eq(15)
          expect(DeploymentLabelModel.map(&:value)).to match_array((36..50).map(&:to_s))
          expect(DeploymentAnnotationModel.count).to eq(15)
          expect(DeploymentAnnotationModel.map(&:value)).to match_array((36..50).map(&:to_s))
        end

        it 'destroys associated historical processes to maintain key constraints' do
          expect(DeploymentModel.count).to eq(0)

          50.times do
            d = DeploymentModel.make(state: DeploymentModel::DEPLOYED_STATE, app: app)
            DeploymentProcessModel.make(deployment: d)
          end

          expect {
            job.perform
          }.not_to raise_error
        end

        context 'multiple apps' do
          let(:app_the_second) { AppModel.make(name: 'app_the_second') }
          let(:app_the_third) { AppModel.make(name: 'app_the_third') }

          it 'prunes deployments on multiple apps' do
            expect(DeploymentModel.count).to eq(0)

            [app, app_the_second, app_the_third].each_with_index do |current_app, app_index|
              total = 50
              (1..total).each do |i|
                DeploymentModel.make(id: i + 1000 * app_index, state: DeploymentModel::DEPLOYED_STATE, app: current_app, created_at: Time.now - total + i)
              end
            end

            job.perform

            expect(DeploymentModel.where(app: app).count).to eq(15)
            expect(DeploymentModel.where(app: app).map(&:id)).to match_array((36..50).to_a)

            expect(DeploymentModel.where(app: app_the_second).count).to eq(15)
            expect(DeploymentModel.where(app: app_the_second).map(&:id)).to match_array((1036..1050).to_a)

            expect(DeploymentModel.where(app: app_the_third).count).to eq(15)
            expect(DeploymentModel.where(app: app_the_third).map(&:id)).to match_array((2036..2050).to_a)
          end
        end

        context 'apps without deployments' do
          let!(:app_without_deployments) { AppModel.make }
          let(:fake_logger) { instance_double(Steno::Logger, info: nil) }

          before do
            allow(Steno).to receive(:logger).and_return(fake_logger)
          end

          it 'only looks at apps that with deployments' do
            job.perform

            expect(fake_logger).to have_received(:info).with('Cleaning up old deployments')
            expect(fake_logger).to have_received(:info) do |s|
              expect(s).not_to match(app_without_deployments.guid)
            end
          end
        end
      end
    end
  end
end
