require 'spec_helper'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  describe Runners do
    let(:config) do
      {
          staging: {
              timeout_in_seconds: 90
          }
      }
    end

    let(:message_bus) do
      instance_double(CfMessageBus::MessageBus)
    end

    let(:dea_pool) do
      instance_double(Dea::Pool)
    end

    let(:package_hash) do
      'fake-package-hash'
    end

    let(:custom_buildpacks_enabled?) do
      true
    end

    let(:buildpack) do
      instance_double(AutoDetectionBuildpack,
        custom?: false
      )
    end

    let(:docker_image) do
      nil
    end

    let(:app) do
      instance_double(App,
        docker_image: docker_image,
        package_hash: package_hash,
        buildpack: buildpack,
        custom_buildpacks_enabled?: custom_buildpacks_enabled?,
        buildpack_specified?: false,
      )
    end

    subject(:runners) do
      Runners.new(config, message_bus, dea_pool)
    end

    def make_diego_app(options={})
      AppFactory.make(options).tap do |app|
        app.package_state = 'STAGED'
        app.diego = true
        app.save
      end
    end

    def make_dea_app(options={})
      AppFactory.make(options).tap do |app|
        app.package_state = 'STAGED'
        app.save
      end
    end

    describe '#runner_for_app' do
      subject(:runner) do
        runners.runner_for_app(app)
      end

      context 'when the app is configured to run on Diego' do
        before do
          allow(app).to receive(:diego?).and_return(true)
        end

        it 'finds a diego backend' do
          expect(runners).to receive(:diego_runner).with(app).and_call_original
          expect(runner).to be_a(Diego::Runner)
        end

        context 'when the app has a docker image' do
          let(:docker_image) { 'foobar' }

          it 'finds a diego backend' do
            expect(runners).to receive(:diego_runner).with(app).and_call_original
            expect(runner).to be_a(Diego::Runner)
          end
        end

        context 'when the app is not configured to run on Diego' do
          before do
            allow(app).to receive(:diego?).and_return(false)
          end

          it 'finds a DEA backend' do
            expect(runners).to receive(:dea_runner).with(app).and_call_original
            expect(runner).to be_a(Dea::Runner)
          end
        end
      end
    end

    describe '#run_with_diego?' do
      let(:diego_app) { make_diego_app }
      let(:dea_app) { make_dea_app }

      it 'returns true for a diego app' do
        expect(runners.run_with_diego?(diego_app)).to be_truthy
      end

      it 'returns false for a dea app' do
        expect(runners.run_with_diego?(dea_app)).to be_falsey
      end
    end

    describe '#diego_apps' do
      before do
        5.times do |i|
          app = make_diego_app(id: i + 1, state: 'STARTED')
          app.add_route(Route.make(space: app.space))
        end

        make_dea_app(id: 99, state: 'STARTED')
      end

      it 'returns apps that have the desired data' do
        last_app = make_diego_app({
          'id' => 6,
          'state' => 'STARTED',
          'package_hash' => 'package-hash',
          'disk_quota' => 1_024,
          'package_state' => 'STAGED',
          'environment_json' => {
            'env-key-3' => 'env-value-3',
            'env-key-4' => 'env-value-4',
          },
          'file_descriptors' => 16_384,
          'instances' => 4,
          'memory' => 1_024,
          'guid' => 'app-guid-6',
          'command' => 'start-command-6',
          'stack' => Stack.make(name: 'stack-6'),
        })

        route1 = Route.make(
          space: last_app.space,
          host: 'arsenio',
          domain: SharedDomain.make(name: 'lo-mein.com'),
        )
        last_app.add_route(route1)

        route2 = Route.make(
          space: last_app.space,
          host: 'conan',
          domain: SharedDomain.make(name: 'doe-mane.com'),
        )
        last_app.add_route(route2)

        last_app.version = 'app-version-6'
        last_app.save

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
        unstaged_app = make_diego_app(id: 6, state: 'STARTED')
        unstaged_app.package_state = 'PENDING'
        unstaged_app.save

        batch = runners.diego_apps(100, 0)

        expect(batch).not_to include(unstaged_app)
      end

      it "does not return apps which aren't expected to be started" do
        stopped_app = make_diego_app(id: 6, state: 'STOPPED')

        batch = runners.diego_apps(100, 0)

        expect(batch).not_to include(stopped_app)
      end

      it 'does not return deleted apps' do
        deleted_app = make_diego_app(id: 6, state: 'STARTED', deleted_at: DateTime.now.utc)

        batch = runners.diego_apps(100, 0)

        expect(batch).not_to include(deleted_app)
      end

      it 'only includes apps that have the diego attribute set' do
        non_diego_app = make_diego_app(id: 6, state: 'STARTED')
        non_diego_app.diego = false
        non_diego_app.save

        batch = runners.diego_apps(100, 0)

        expect(batch).not_to include(non_diego_app)
      end

      it 'loads all of the associations eagerly' do
        expect {
          runners.diego_apps(100, 0).each do |app|
            app.current_droplet
            app.space
            app.stack
            app.routes
            app.service_bindings
            app.routes.map(&:domain)
          end
        }.to have_queried_db_times(/SELECT/, [
          :apps,
          :droplets,
          :spaces,
          :stacks,
          :routes,
          :service_bindings,
          :domain
        ].freeze.length)
      end
    end

    describe '#diego_apps_from_process_guids' do
      before do
        5.times do
          app = make_diego_app(state: 'STARTED')
          app.add_route(Route.make(space: app.space))
        end

        expect(App.all.length).to eq(5)
      end

      it 'does not return unstaged apps' do
        unstaged_app = make_diego_app(state: 'STARTED')
        unstaged_app.package_state = 'PENDING'
        unstaged_app.save

        batch = runners.diego_apps_from_process_guids(Diego::ProcessGuid.from_app(unstaged_app))

        expect(batch).not_to include(unstaged_app)
      end

      it 'does not return apps that are stopped' do
        stopped_app = make_diego_app(state: 'STOPPED')

        batch = runners.diego_apps_from_process_guids(Diego::ProcessGuid.from_app(stopped_app))

        expect(batch).not_to include(stopped_app)
      end

      it 'does not return deleted apps' do
        deleted_app = make_diego_app(state: 'STARTED', deleted_at: DateTime.now.utc)

        batch = runners.diego_apps_from_process_guids(Diego::ProcessGuid.from_app(deleted_app))

        expect(batch).not_to include(deleted_app)
      end

      it 'only includes diego apps' do
        non_diego_app = make_diego_app(state: 'STARTED')
        non_diego_app.diego = false
        non_diego_app.save

        batch = runners.diego_apps_from_process_guids(Diego::ProcessGuid.from_app(non_diego_app))

        expect(batch).not_to include(non_diego_app)
      end

      it 'accepts a process guid or an array of process guids' do
        app = App.where(diego: true).order(:id).first
        process_guid = Diego::ProcessGuid.from_app(app)

        expect(runners.diego_apps_from_process_guids(process_guid)).to eq([app])
        expect(runners.diego_apps_from_process_guids([process_guid])).to eq([app])
      end

      it 'returns diego apps for each requested process guid' do
        diego_apps = App.where(diego: true).all
        diego_guids = diego_apps.map { |app| Diego::ProcessGuid.from_app(app) }

        expect(runners.diego_apps_from_process_guids(diego_guids)).to match_array(diego_apps)
      end

      it 'loads all of the associations eagerly' do
        diego_apps = App.where(diego: true).all
        diego_guids = diego_apps.map { |app| Diego::ProcessGuid.from_app(app) }

        expect {
          runners.diego_apps_from_process_guids(diego_guids).each do |app|
            app.current_droplet
            app.space
            app.stack
            app.routes
            app.service_bindings
            app.routes.map(&:domain)
          end
        }.to have_queried_db_times(/SELECT/, [
          :apps,
          :droplets,
          :spaces,
          :stacks,
          :routes,
          :service_bindings,
          :domain
        ].freeze.length)
      end

      context 'when the process guid is not found' do
        it 'does not return an app' do
          app = App.where(diego: true).order(:id).first
          process_guid = Diego::ProcessGuid.from_app(app)

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
      before do
        5.times { make_diego_app(state: 'STARTED') }
        expect(App.all.length).to eq(5)
      end

      it 'respects the batch_size' do
        data_count = [3, 5].map do |batch_size|
          runners.diego_apps_cache_data(batch_size, 0).count
        end

        expect(data_count).to eq([3, 5])
      end

      it 'returns data for non-intersecting apps across subsequent batches' do
        first_batch = runners.diego_apps_cache_data(3, 0)
        expect(first_batch.count).to eq(3)

        last_id = first_batch.last[0]
        second_batch = runners.diego_apps_cache_data(3, last_id)
        expect(second_batch.count).to eq(2)
      end

      it 'does not return unstaged apps' do
        unstaged_app = make_diego_app(state: 'STARTED')
        unstaged_app.package_state = 'PENDING'
        unstaged_app.save

        batch = runners.diego_apps_cache_data(100, 0)
        app_ids = batch.map { |data| data[0] }

        expect(app_ids).not_to include(unstaged_app.id)
      end

      it 'does not return apps that are stopped' do
        stopped_app = make_diego_app(state: 'STOPPED')

        batch = runners.diego_apps_cache_data(100, 0)
        app_ids = batch.map { |data| data[0] }

        expect(app_ids).not_to include(stopped_app.id)
      end

      it 'does not return deleted apps' do
        deleted_app = make_diego_app(state: 'STARTED', deleted_at: DateTime.now.utc)

        batch = runners.diego_apps_cache_data(100, 0)
        app_ids = batch.map { |data| data[0] }

        expect(app_ids).not_to include(deleted_app.id)
      end

      it 'only includes diego apps' do
        non_diego_app = make_diego_app(state: 'STARTED')
        non_diego_app.diego = false
        non_diego_app.save

        batch = runners.diego_apps_cache_data(100, 0)
        app_ids = batch.map { |data| data[0] }

        expect(app_ids).not_to include(non_diego_app.id)
      end

      it 'acquires the data in one select' do
        expect {
          runners.diego_apps_cache_data(100, 0)
        }.to have_queried_db_times(/SELECT.*FROM.*apps.*/, 1)
      end

      context 'with Docker app' do
        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
        end

        let!(:docker_app) do
          make_diego_app(docker_image: 'some-image', state: 'STARTED')
        end

        context 'when docker is enabled' do
          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: true)
          end

          it 'returns docker apps' do
            batch = runners.diego_apps_cache_data(100, 0)
            app_ids = batch.map { |data| data[0] }

            expect(app_ids).to include(docker_app.id)
          end
        end

        context 'when docker is disabled' do
          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
          end

          it 'does not return docker apps' do
            batch = runners.diego_apps_cache_data(100, 0)
            app_ids = batch.map { |data| data[0] }

            expect(app_ids).not_to include(docker_app.id)
          end
        end
      end
    end

    describe '#dea_apps_hm9k' do
      before do
        allow(runners).to receive(:diego_running_optional?).and_return(true)

        5.times do |i|
          app = make_dea_app(id: i + 1, state: 'STARTED')
          app.add_route(Route.make(space: app.space))
        end
      end

      it 'returns apps that have the desired data' do
        last_app = make_dea_app({
          'id' => 6,
          'state' => 'STARTED',
          'package_hash' => 'package-hash',
          'disk_quota' => 1_024,
          'package_state' => 'STAGED',
          'environment_json' => {
            'env-key-3' => 'env-value-3',
            'env-key-4' => 'env-value-4',
          },
          'file_descriptors' => 16_384,
          'instances' => 4,
          'memory' => 1_024,
          'guid' => 'app-guid-6',
          'command' => 'start-command-6',
          'stack' => Stack.make(name: 'stack-6'),
        })

        route1 = Route.make(
          space: last_app.space,
          host: 'arsenio',
          domain: SharedDomain.make(name: 'lo-mein.com'),
        )
        last_app.add_route(route1)

        route2 = Route.make(
          space: last_app.space,
          host: 'conan',
          domain: SharedDomain.make(name: 'doe-mane.com'),
        )
        last_app.add_route(route2)

        last_app.version = 'app-version-6'
        last_app.save

        apps, _ = runners.dea_apps_hm9k(100, 0)
        expect(apps.count).to eq(6)

        expect(apps.last).to include(
          'id' => last_app.guid, 'instances' => last_app.instances,
          'state' => last_app.state, 'memory' => last_app.memory,
          'package_state' => last_app.package_state, 'version' => last_app.version,
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

      it 'does not return deleted apps' do
        deleted_app = make_dea_app(id: 6, state: 'STARTED', deleted_at: DateTime.now.utc)

        batch, _ = runners.dea_apps_hm9k(100, 0)

        expect(batch).not_to include(deleted_app)
      end

      it 'does not return stopped apps' do
        stopped_app = make_dea_app(id: 6, state: 'STOPPED')

        batch, _ = runners.dea_apps_hm9k(100, 0)

        guids = batch.map { |entry| entry['id'] }
        expect(guids).not_to include(stopped_app.guid)
      end

      it 'does not return apps that failed to stage' do
        staging_failed_app = AppFactory.make(id: 6, state: 'STARTED', package_state: 'FAILED')

        batch, _ = runners.dea_apps_hm9k(100, 0)

        guids = batch.map { |entry| entry['id'] }
        expect(guids).not_to include(staging_failed_app.guid)
      end

      it 'returns apps that have not yet been staged' do
        staging_pending_app = AppFactory.make(id: 6, state: 'STARTED', package_state: 'PENDING')

        batch, _ = runners.dea_apps_hm9k(100, 0)

        guids = batch.map { |entry| entry['id'] }
        expect(guids).to include(staging_pending_app.guid)
      end
    end
  end
end
