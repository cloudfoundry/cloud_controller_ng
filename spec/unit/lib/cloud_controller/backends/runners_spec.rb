require 'spec_helper'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  RSpec.describe Runners do
    subject(:runners) { Runners.new(config, message_bus, dea_pool) }

    let(:config) do
      {
        staging: {
          timeout_in_seconds: 90
        }
      }
    end
    let(:message_bus) { instance_double(CfMessageBus::MessageBus) }
    let(:dea_pool) { instance_double(Dea::Pool) }
    let(:package_hash) { 'fake-package-hash' }
    let(:custom_buildpacks_enabled?) { true }
    let(:buildpack) { instance_double(AutoDetectionBuildpack, custom?: false) }
    let(:docker_image) { nil }

    describe '#runner_for_app' do
      subject(:runner) do
        runners.runner_for_app(app)
      end

      context 'when the app is configured to run on Diego' do
        let(:app) { AppFactory.make(diego: true) }

        it 'finds a diego backend' do
          expect(runners).to receive(:diego_runner).with(app).and_call_original
          expect(runner).to be_a(Diego::Runner)
        end

        context 'when the app has a docker image' do
          let(:app) { AppFactory.make(:docker, docker_image: 'foobar') }

          it 'finds a diego backend' do
            expect(runners).to receive(:diego_runner).with(app).and_call_original
            expect(runner).to be_a(Diego::Runner)
          end
        end
      end

      context 'when the app is not configured to run on Diego' do
        let(:app) { AppFactory.make }

        it 'finds a DEA backend' do
          expect(runners).to receive(:dea_runner).with(app).and_call_original
          expect(runner).to be_a(Dea::Runner)
        end
      end
    end

    describe '#run_with_diego?' do
      let(:diego_app) { AppFactory.make(diego: true) }
      let(:dea_app) { AppFactory.make }

      it 'returns true for a diego app' do
        expect(runners.run_with_diego?(diego_app)).to be_truthy
      end

      it 'returns false for a dea app' do
        expect(runners.run_with_diego?(dea_app)).to be_falsey
      end
    end

    describe '#diego_apps' do
      let!(:diego_app1) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app2) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app3) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app4) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app5) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:dea_app) { AppFactory.make(state: 'STARTED') }

      it 'returns apps that have the desired data' do
        last_app = AppFactory.make(diego: true, state: 'STARTED', version: 'app-version-6')

        apps = runners.diego_apps(100, 0)

        expect(apps.count).to eq(6)

        expect(apps.last.to_json).to match_object(last_app.to_json)
      end

      it 'respects the batch_size' do
        app_counts = [3, 5].map do |batch_size|
          runners.diego_apps(batch_size, 0).count
        end

        expect(app_counts).to eq([3, 5])
      end

      it 'returns non-intersecting apps across subsequent batches' do
        first_batch = runners.diego_apps(3, 0)
        expect(first_batch.count).to eq(3)

        second_batch = runners.diego_apps(3, first_batch.last.id)
        expect(second_batch.count).to eq(2)

        expect(second_batch & first_batch).to eq([])
      end

      it 'does not return unstaged apps' do
        unstaged_app = AppFactory.make(diego: true, state: 'STARTED')
        unstaged_app.current_droplet.destroy

        batch = runners.diego_apps(100, 0)

        expect(batch).not_to include(unstaged_app)
      end

      it "does not return apps which aren't expected to be started" do
        stopped_app = AppFactory.make(diego: true, state: 'STOPPED')

        batch = runners.diego_apps(100, 0)

        expect(batch).not_to include(stopped_app)
      end

      it 'only includes apps that have the diego attribute set' do
        batch = runners.diego_apps(100, 0)
        expect(batch).not_to include(dea_app)
      end
    end

    describe '#diego_apps_from_process_guids' do
      let!(:diego_app1) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app2) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app3) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app4) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app5) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:dea_app) { AppFactory.make(state: 'STARTED') }

      it 'does not return unstaged apps' do
        unstaged_app = AppFactory.make(diego: true, state: 'STARTED')
        unstaged_app.current_droplet.destroy

        batch = runners.diego_apps_from_process_guids(Diego::ProcessGuid.from_process(unstaged_app))

        expect(batch).not_to include(unstaged_app)
      end

      it 'does not return apps that are stopped' do
        stopped_app = AppFactory.make(diego: true, state: 'STOPPED')

        batch = runners.diego_apps_from_process_guids(Diego::ProcessGuid.from_process(stopped_app))

        expect(batch).not_to include(stopped_app)
      end

      it 'only includes diego apps' do
        batch = runners.diego_apps_from_process_guids(Diego::ProcessGuid.from_process(dea_app))

        expect(batch).not_to include(dea_app)
      end

      it 'accepts a process guid or an array of process guids' do
        app          = App.where(diego: true).order(:id).first
        process_guid = Diego::ProcessGuid.from_process(app)

        expect(runners.diego_apps_from_process_guids(process_guid)).to eq([app])
        expect(runners.diego_apps_from_process_guids([process_guid])).to eq([app])
      end

      it 'returns diego apps for each requested process guid' do
        diego_apps  = App.where(diego: true).all
        diego_guids = diego_apps.map { |app| Diego::ProcessGuid.from_process(app) }

        expect(runners.diego_apps_from_process_guids(diego_guids)).to match_array(diego_apps)
      end

      context 'when the process guid is not found' do
        it 'does not return an app' do
          app          = App.where(diego: true).order(:id).first
          process_guid = Diego::ProcessGuid.from_process(app)

          expect {
            app.set_new_version
            app.save
          }.to change {
            runners.diego_apps_from_process_guids(process_guid)
          }.from([app]).to([])
        end
      end
    end

    describe '#diego_apps_cache_data' do
      let!(:diego_app1) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app2) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app3) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app4) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:diego_app5) { AppFactory.make(diego: true, state: 'STARTED') }
      let!(:dea_app) { AppFactory.make(state: 'STARTED') }

      it 'respects the batch_size' do
        data_count = [3, 5].map do |batch_size|
          runners.diego_apps_cache_data(batch_size, 0).count
        end

        expect(data_count).to eq([3, 5])
      end

      it 'returns data for non-intersecting apps across subsequent batches' do
        first_batch = runners.diego_apps_cache_data(3, 0)
        expect(first_batch.count).to eq(3)

        last_id      = first_batch.last[0]
        second_batch = runners.diego_apps_cache_data(3, last_id)
        expect(second_batch.count).to eq(2)
      end

      it 'does not return unstaged apps' do
        unstaged_app = AppFactory.make(diego: true, state: 'STARTED')
        unstaged_app.current_droplet.destroy

        batch   = runners.diego_apps_cache_data(100, 0)
        app_ids = batch.map { |data| data[0] }

        expect(app_ids).not_to include(unstaged_app.id)
      end

      it 'does not return apps that are stopped' do
        stopped_app = AppFactory.make(diego: true, state: 'STOPPED')

        batch   = runners.diego_apps_cache_data(100, 0)
        app_ids = batch.map { |data| data[0] }

        expect(app_ids).not_to include(stopped_app.id)
      end

      it 'only includes diego apps' do
        batch   = runners.diego_apps_cache_data(100, 0)
        app_ids = batch.map { |data| data[0] }

        expect(app_ids).not_to include(dea_app.id)
      end

      it 'acquires the data in one select' do
        expect {
          runners.diego_apps_cache_data(100, 0)
        }.to have_queried_db_times(/SELECT.*FROM.*processes.*/, 1)
      end

      context 'with Docker app' do
        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
        end

        let!(:docker_app) do
          AppFactory.make(:docker, docker_image: 'some-image', state: 'STARTED')
        end

        context 'when docker is enabled' do
          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: true)
          end

          it 'returns docker apps' do
            batch   = runners.diego_apps_cache_data(100, 0)
            app_ids = batch.map { |data| data[0] }

            expect(app_ids).to include(docker_app.id)
          end
        end

        context 'when docker is disabled' do
          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
          end

          it 'does not return docker apps' do
            batch   = runners.diego_apps_cache_data(100, 0)
            app_ids = batch.map { |data| data[0] }

            expect(app_ids).not_to include(docker_app.id)
          end
        end
      end
    end

    describe '#dea_apps_hm9k' do
      let!(:dea_app1) { AppFactory.make(state: 'STARTED') }
      let!(:dea_app2) { AppFactory.make(state: 'STARTED') }
      let!(:dea_app3) { AppFactory.make(state: 'STARTED') }
      let!(:dea_app4) { AppFactory.make(state: 'STARTED') }
      let!(:dea_app5) { AppFactory.make(state: 'STARTED') }

      it 'returns apps that have the desired data' do
        last_app = AppFactory.make(state: 'STARTED')

        apps, _ = runners.dea_apps_hm9k(100, 0)
        expect(apps.count).to eq(6)

        expect(apps.last).to include(
          'id'            => last_app.guid,
          'instances'     => last_app.instances,
          'state'         => last_app.state,
          'memory'        => last_app.memory,
          'package_state' => 'STAGED',
          'version'       => last_app.version,
        )
        expect(apps.last).to have_key('updated_at')
      end

      it 'respects the batch_size' do
        app_counts = [3, 5].map do |batch_size|
          runners.dea_apps_hm9k(batch_size, 0)[0].count
        end

        expect(app_counts).to eq([3, 5])
      end

      it 'returns non-intersecting apps across subsequent batches' do
        first_batch, next_id = runners.dea_apps_hm9k(3, 0)
        expect(first_batch.count).to eq(3)

        second_batch, _ = runners.dea_apps_hm9k(3, next_id)
        expect(second_batch.count).to eq(2)

        expect(second_batch & first_batch).to eq([])
      end

      it 'does not return stopped apps' do
        stopped_app = AppFactory.make(state: 'STOPPED')

        batch, _ = runners.dea_apps_hm9k(100, 0)

        guids = batch.map { |entry| entry['id'] }
        expect(guids).not_to include(stopped_app.guid)
      end

      it 'does not return apps that failed to stage' do
        staging_failed_app = dea_app1
        DropletModel.make(package: dea_app1.latest_package, app: dea_app1.app, state: DropletModel::FAILED_STATE)

        batch, _ = runners.dea_apps_hm9k(100, 0)

        guids = batch.map { |entry| entry['id'] }
        expect(guids).not_to include(staging_failed_app.guid)
      end

      it 'returns apps that have not yet been staged' do
        staging_pending_app = dea_app1
        PackageModel.make(app: dea_app1.app, state: PackageModel::PENDING_STATE)

        batch, _ = runners.dea_apps_hm9k(100, 0)

        guids = batch.map { |entry| entry['id'] }
        expect(guids).to include(staging_pending_app.guid)
      end
    end
  end
end
