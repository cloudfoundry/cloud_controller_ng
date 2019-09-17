require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PruneExcessAppRevisions, job_context: :worker do
      let(:max_retained_revisions_per_app) { 15 }
      subject(:job) { PruneExcessAppRevisions.new(max_retained_revisions_per_app) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:prune_excess_app_revisions)
      end

      describe '#perform' do
        let(:app) { AppModel.make(name: 'app') }

        it 'deletes all the revisions over the limit' do
          expect(RevisionModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            RevisionModel.make(version: i, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(RevisionModel.count).to eq(max_retained_revisions_per_app)
          expect(RevisionModel.map(&:version)).to match_array((36..50).to_a)
        end

        it 'destroys metadata associated with pruned revisions' do
          expect(RevisionModel.count).to eq(0)
          expect(RevisionLabelModel.count).to eq(0)
          expect(RevisionAnnotationModel.count).to eq(0)

          total = 50
          (1..50).each do |i|
            revision = RevisionModel.make(version: i, app: app, created_at: Time.now - total + i)
            RevisionAnnotationModel.make(revision: revision, key: i, value: i)
            RevisionLabelModel.make(revision: revision, key_name: i, value: i)
          end

          job.perform

          expect(RevisionModel.count).to eq(15)
          expect(RevisionModel.map(&:version)).to match_array((36..50).to_a)
          expect(RevisionLabelModel.count).to eq(15)
          expect(RevisionLabelModel.map(&:value)).to match_array((36..50).map(&:to_s))
          expect(RevisionAnnotationModel.count).to eq(15)
          expect(RevisionAnnotationModel.map(&:value)).to match_array((36..50).map(&:to_s))
        end

        it 'destroys associated process commands' do
          expect(RevisionModel.count).to eq(0)

          process_commands = []
          50.times do |i|
            revision = RevisionModel.make(app: app)
            process_commands << revision.process_commands
          end
          process_commands.flatten!

          expect {
            job.perform
          }.to change { RevisionProcessCommandModel.count }.by(-35)

          expect(process_commands[0...35].none?(&:exists?))
          expect(process_commands[35...50].all?(&:exists?))
        end

        context 'multiple apps' do
          let(:app_the_second) { AppModel.make(name: 'app_the_second') }
          let(:app_the_third) { AppModel.make(name: 'app_the_third') }

          it 'prunes revisions on multiple apps' do
            expect(RevisionModel.count).to eq(0)

            [app, app_the_second, app_the_third].each_with_index do |current_app, app_index|
              total = 50
              (1..total).each do |i|
                RevisionModel.make(version: i + 1000 * app_index, app: current_app, created_at: Time.now - total + i)
              end
            end

            job.perform

            expect(RevisionModel.where(app: app).count).to eq(15)
            expect(RevisionModel.where(app: app).map(&:version)).to match_array((36..50).to_a)

            expect(RevisionModel.where(app: app_the_second).count).to eq(15)
            expect(RevisionModel.where(app: app_the_second).map(&:version)).to match_array((1036..1050).to_a)

            expect(RevisionModel.where(app: app_the_third).count).to eq(15)
            expect(RevisionModel.where(app: app_the_third).map(&:version)).to match_array((2036..2050).to_a)
          end
        end

        context 'apps without revisions' do
          let!(:app_without_revisions) { AppModel.make }
          let(:fake_logger) { instance_double(Steno::Logger, info: nil) }

          before do
            allow(Steno).to receive(:logger).and_return(fake_logger)
          end

          it 'only looks at apps that with revisions' do
            job.perform

            expect(fake_logger).to have_received(:info).with('Cleaning up excess app revisions')
            expect(fake_logger).to have_received(:info) do |s|
              expect(s).not_to match(app_without_revisions.guid)
            end
          end
        end
      end
    end
  end
end
