require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PruneCompletedBuilds, job_context: :worker do
      let(:max_retained_builds_per_app) { 15 }
      subject(:job) { PruneCompletedBuilds.new(max_retained_builds_per_app) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:prune_completed_builds)
      end

      describe '#perform' do
        let(:app) { AppModel.make(name: 'app') }

        it 'deletes all the staged builds over the limit' do
          expect(BuildModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            BuildModel.make(id: i, state: BuildModel::STAGED_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(BuildModel.count).to eq(15)
          expect(BuildModel.map(&:id)).to match_array((36..50).to_a)
        end

        it 'deletes all failed builds over the limit' do
          expect(BuildModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            BuildModel.make(id: i, state: BuildModel::FAILED_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(BuildModel.count).to eq(15)
          expect(BuildModel.map(&:id)).to match_array((36..50).to_a)
        end

        it 'does NOT delete any staging builds over the limit' do
          expect(BuildModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            BuildModel.make(id: i, state: BuildModel::STAGING_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(BuildModel.count).to eq(50)
          expect(BuildModel.map(&:id)).to match_array((1..50).to_a)
        end

        it 'does not delete in-flight builds over the limit' do
          total = 60
          (1..20).each do |i|
            BuildModel.make(id: i, state: BuildModel::STAGED_STATE, app: app, created_at: Time.now - total + i)
          end
          (21..40).each do |i|
            BuildModel.make(id: i, state: BuildModel::STAGING_STATE, app: app, created_at: Time.now - total + i)
          end
          (41..60).each do |i|
            BuildModel.make(id: i, state: BuildModel::STAGED_STATE, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(BuildModel.count).to be(35)
          expect(BuildModel.order(Sequel.asc(:created_at)).map(&:id)).to eq((21..40).to_a + (46..60).to_a)
        end

        it 'calls destroy on the BuildModel so association dependencies are respected' do
          expect(BuildModel.count).to eq(0)

          50.times do
            b = BuildModel.make(state: BuildModel::STAGED_STATE, app: app)
            BuildpackLifecycleDataModel.make(build: b)
          end

          expect {
            job.perform
          }.not_to raise_error
        end

        context 'multiple apps' do
          let(:app_the_second) { AppModel.make(name: 'app_the_second') }
          let(:app_the_third) { AppModel.make(name: 'app_the_third') }

          it 'prunes builds on multiple apps' do
            expect(BuildModel.count).to eq(0)

            [app, app_the_second, app_the_third].each_with_index do |current_app, app_index|
              total = 50
              (1..total).each do |i|
                BuildModel.make(id: i + 1000 * app_index, state: BuildModel::STAGED_STATE, app: current_app, created_at: Time.now - total + i)
              end
            end

            job.perform

            expect(BuildModel.where(app: app).count).to eq(15)
            expect(BuildModel.where(app: app).map(&:id)).to match_array((36..50).to_a)

            expect(BuildModel.where(app: app_the_second).count).to eq(15)
            expect(BuildModel.where(app: app_the_second).map(&:id)).to match_array((1036..1050).to_a)

            expect(BuildModel.where(app: app_the_third).count).to eq(15)
            expect(BuildModel.where(app: app_the_third).map(&:id)).to match_array((2036..2050).to_a)
          end
        end

        context 'apps without builds' do
          let!(:app_without_builds) { AppModel.make }
          let(:fake_logger) { instance_double(Steno::Logger, info: nil) }

          before do
            allow(Steno).to receive(:logger).and_return(fake_logger)
          end

          it 'only looks at apps that have builds' do
            job.perform

            expect(fake_logger).to have_received(:info).with('Cleaning up old builds')
            expect(fake_logger).to have_received(:info) do |s|
              expect(s).not_to match(app_without_builds.guid)
            end
          end
        end
      end
    end
  end
end
