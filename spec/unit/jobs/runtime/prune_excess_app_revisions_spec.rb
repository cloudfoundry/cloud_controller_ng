require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PruneExcessAppRevisions, job_context: :worker do
      let(:max_retained_revisions_per_app) { 3 }

      subject(:job) { PruneExcessAppRevisions.new(max_retained_revisions_per_app) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:prune_excess_app_revisions)
      end

      describe '#perform' do
        let(:app) { create(:app_model, name: 'app') }

        it 'deletes all the revisions over the limit' do
          expect(RevisionModel.count).to eq(0)

          total = 8
          (1..total).each do |i|
            create(:revision_model, version: i, app: app, created_at: Time.now - total + i)
          end

          job.perform

          expect(RevisionModel.count).to eq(max_retained_revisions_per_app)
          expect(RevisionModel.map(&:version)).to match_array((6..8).to_a)
        end

        context 'logging' do
          let(:fake_logger) { instance_double(Steno::Logger, info: nil) }

          before do
            allow(Steno).to receive(:logger).and_return(fake_logger)
          end

          it 'logs the number of revisions deleted' do
            expect(RevisionModel.count).to eq(0)

            total = 8
            (1..total).each do |i|
              create(:revision_model, version: i, app: app, created_at: Time.now - total + i)
            end

            job.perform

            expect(fake_logger).to have_received(:info).with('Cleaning up excess app revisions')
            expect(fake_logger).to have_received(:info).with("Cleaned up 5 revision rows for app #{app.guid}")
          end
        end

        it 'destroys metadata associated with pruned revisions' do
          expect(RevisionModel.count).to eq(0)
          expect(RevisionLabelModel.count).to eq(0)
          expect(RevisionAnnotationModel.count).to eq(0)

          total = 8
          (1..total).each do |i|
            revision = create(:revision_model, version: i, app: app, created_at: Time.now - total + i)
            create(:revision_annotation_model, revision: revision, key_name: i, value: i)
            create(:revision_label_model, revision: revision, key_name: i, value: i)
          end

          job.perform

          expect(RevisionModel.count).to eq(3)
          expect(RevisionModel.map(&:version)).to match_array((6..8).to_a)
          expect(RevisionLabelModel.count).to eq(3)
          expect(RevisionLabelModel.map(&:value)).to match_array((6..8).map(&:to_s))
          expect(RevisionAnnotationModel.count).to eq(3)
          expect(RevisionAnnotationModel.map(&:value)).to match_array((6..8).map(&:to_s))
        end

        it 'destroys associated process commands' do
          expect(RevisionModel.count).to eq(0)

          process_commands = []
          8.times do |_i|
            revision = create(:revision_model, app:)
            process_commands << revision.process_commands
          end
          process_commands.flatten!

          expect do
            job.perform
          end.to change(RevisionProcessCommandModel, :count).by(-5)

          expect(process_commands[0...5].none?(&:exists?))
          expect(process_commands[5...8].all?(&:exists?))
        end

        context 'multiple apps' do
          let(:app_the_second) { create(:app_model, name: 'app_the_second') }
          let(:app_the_third) { create(:app_model, name: 'app_the_third') }

          it 'prunes revisions on multiple apps' do
            expect(RevisionModel.count).to eq(0)

            [app, app_the_second, app_the_third].each_with_index do |current_app, app_index|
              total = 8
              (1..total).each do |i|
                create(:revision_model, version: i + (1000 * app_index), app: current_app, created_at: Time.now - total + i)
              end
            end

            job.perform

            expect(RevisionModel.where(app:).count).to eq(3)
            expect(RevisionModel.where(app:).map(&:version)).to match_array((6..8).to_a)

            expect(RevisionModel.where(app: app_the_second).count).to eq(3)
            expect(RevisionModel.where(app: app_the_second).map(&:version)).to match_array((1006..1008).to_a)

            expect(RevisionModel.where(app: app_the_third).count).to eq(3)
            expect(RevisionModel.where(app: app_the_third).map(&:version)).to match_array((2006..2008).to_a)
          end
        end

        context 'apps without revisions' do
          let!(:app_without_revisions) { create(:app_model) }
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
