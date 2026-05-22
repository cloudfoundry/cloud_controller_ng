require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe LifecycleTypeBackfill, job_context: :worker do
      subject(:job) { LifecycleTypeBackfill.new }

      let(:db) { Sequel::Model.db }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to eq(:lifecycle_type_backfill)
      end

      it 'has max_attempts of 1' do
        expect(job.max_attempts).to eq(1)
      end

      describe '#perform' do
        context 'when the lifecycle_type column is missing on every table' do
          let!(:app) { create(:app_model) }
          let!(:droplet) { create(:droplet_model) }
          let!(:build) { create(:build_model) }

          before do
            db[:apps].where(guid: app.guid).update(lifecycle_type: nil)
            db[:droplets].where(guid: droplet.guid).update(lifecycle_type: nil)
            db[:builds].where(guid: build.guid).update(lifecycle_type: nil)
            allow(db).to receive(:schema).and_call_original
            %i[apps droplets builds].each do |table|
              allow(db).to receive(:schema).with(table, reload: true).and_return(
                [[:guid, {}], [:name, {}]]
              )
            end
          end

          it 'does not issue any UPDATE statements' do
            expect { job.perform }.to have_queried_db_times(/update .(apps|droplets|builds). set/i, 0)
          end

          it 'leaves NULL rows untouched' do
            job.perform
            expect(db[:apps].where(guid: app.guid).get(:lifecycle_type)).to be_nil
            expect(db[:droplets].where(guid: droplet.guid).get(:lifecycle_type)).to be_nil
            expect(db[:builds].where(guid: build.guid).get(:lifecycle_type)).to be_nil
          end
        end

        context 'when no rows have NULL lifecycle_type on any table' do
          before do
            create(:app_model)
            create(:droplet_model)
            create(:build_model)
          end

          it 'does not issue any UPDATE statements' do
            expect { job.perform }.to have_queried_db_times(/update .(apps|droplets|builds). set/i, 0)
          end
        end

        context 'when there are apps with NULL lifecycle_type' do
          let(:buildpack_app) { create(:app_model) }
          let(:cnb_app) { create(:app_model, :cnb) }
          let(:docker_app) { create(:app_model, :docker) }

          before do
            db[:apps].where(guid: [buildpack_app.guid, cnb_app.guid, docker_app.guid]).update(lifecycle_type: nil)
          end

          it 'sets lifecycle_type accordingly' do
            job.perform
            expect(db[:apps].where(guid: buildpack_app.guid).get(:lifecycle_type)).to eq(BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
            expect(db[:apps].where(guid: cnb_app.guid).get(:lifecycle_type)).to eq(CNBLifecycleDataModel::LIFECYCLE_TYPE)
            expect(db[:apps].where(guid: docker_app.guid).get(:lifecycle_type)).to eq(DockerLifecycleDataModel::LIFECYCLE_TYPE)
          end

          it 'does not touch updated_at' do
            original_updated_at = db[:apps].where(guid: [buildpack_app.guid, cnb_app.guid, docker_app.guid]).select_map(%i[guid updated_at]).to_h
            job.perform
            expect(db[:apps].where(guid: [buildpack_app.guid, cnb_app.guid, docker_app.guid]).select_map(%i[guid updated_at]).to_h).to eq(original_updated_at)
          end
        end

        context 'when there are droplets with NULL lifecycle_type' do
          let(:buildpack_droplet) { create(:droplet_model) }
          let(:cnb_droplet) { create(:droplet_model, :cnb) }
          let(:docker_droplet) { create(:droplet_model, :docker) }

          before do
            db[:droplets].where(guid: [buildpack_droplet.guid, cnb_droplet.guid, docker_droplet.guid]).update(lifecycle_type: nil)
          end

          it 'sets lifecycle_type accordingly' do
            job.perform
            expect(db[:droplets].where(guid: buildpack_droplet.guid).get(:lifecycle_type)).to eq(BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
            expect(db[:droplets].where(guid: cnb_droplet.guid).get(:lifecycle_type)).to eq(CNBLifecycleDataModel::LIFECYCLE_TYPE)
            expect(db[:droplets].where(guid: docker_droplet.guid).get(:lifecycle_type)).to eq(DockerLifecycleDataModel::LIFECYCLE_TYPE)
          end

          it 'does not touch updated_at' do
            original_updated_at = db[:droplets].where(guid: [buildpack_droplet.guid, cnb_droplet.guid, docker_droplet.guid]).select_map(%i[guid updated_at]).to_h
            job.perform
            expect(db[:droplets].where(guid: [buildpack_droplet.guid, cnb_droplet.guid, docker_droplet.guid]).select_map(%i[guid updated_at]).to_h).to eq(original_updated_at)
          end
        end

        context 'when there are builds with NULL lifecycle_type' do
          let(:buildpack_build) { create(:build_model) }
          let(:cnb_build) { create(:build_model, :cnb) }
          let(:docker_build) { create(:build_model, :docker) }

          before do
            db[:builds].where(guid: [buildpack_build.guid, cnb_build.guid, docker_build.guid]).update(lifecycle_type: nil)
          end

          it 'sets lifecycle_type accordingly' do
            job.perform
            expect(db[:builds].where(guid: buildpack_build.guid).get(:lifecycle_type)).to eq(BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
            expect(db[:builds].where(guid: cnb_build.guid).get(:lifecycle_type)).to eq(CNBLifecycleDataModel::LIFECYCLE_TYPE)
            expect(db[:builds].where(guid: docker_build.guid).get(:lifecycle_type)).to eq(DockerLifecycleDataModel::LIFECYCLE_TYPE)
          end

          it 'does not touch updated_at' do
            original_updated_at = db[:builds].where(guid: [buildpack_build.guid, cnb_build.guid, docker_build.guid]).select_map(%i[guid updated_at]).to_h
            job.perform
            expect(db[:builds].where(guid: [buildpack_build.guid, cnb_build.guid, docker_build.guid]).select_map(%i[guid updated_at]).to_h).to eq(original_updated_at)
          end
        end

        context 'with more rows than batch_size * batches_per_run' do
          subject(:job) { LifecycleTypeBackfill.new(batch_size: 2, batches_per_run: 2) }

          before do
            create_list(:app_model, 5)
            db[:apps].update(lifecycle_type: nil)
          end

          it 'updates at most batch_size * batches_per_run rows in a single perform' do
            expect { job.perform }.to change { db[:apps].where(lifecycle_type: nil).count }.from(5).to(1)
          end

          it 'processes the remainder on the next perform' do
            job.perform
            job.perform
            expect(db[:apps].where(lifecycle_type: nil).count).to eq(0)
          end
        end

        context 'with fewer rows than batch_size' do
          subject(:job) { LifecycleTypeBackfill.new(batch_size: 2, batches_per_run: 2) }

          before do
            create(:app_model)
            db[:apps].update(lifecycle_type: nil)
          end

          it 'updates every NULL row in a single perform' do
            job.perform
            expect(db[:apps].where(lifecycle_type: nil).count).to eq(0)
          end

          it 'issues exactly one SELECT for guids, subsequent batch is skipped' do
            expect { job.perform }.to have_queried_db_times(/select .guid. from .apps. where \(.lifecycle_type. is null\)/i, 1)
          end
        end

        context 'when batches_per_run is -1 (drain mode)' do
          subject(:job) { LifecycleTypeBackfill.new(batch_size: 2, batches_per_run: -1) }

          before do
            create_list(:app_model, 5)
            db[:apps].update(lifecycle_type: nil)
          end

          it 'keeps batching until no NULL rows remain' do
            job.perform
            expect(db[:apps].where(lifecycle_type: nil).count).to eq(0)
          end
        end
      end
    end
  end
end
