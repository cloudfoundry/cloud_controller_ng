require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::Dea::Client do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:dea_pool) { double(:dea_pool) }
    let(:num_service_instances) { 3 }
    let(:app) do
      AppFactory.make.tap do |app|
        num_service_instances.times do
          instance = ManagedServiceInstance.make(space: app.space)
          binding = ServiceBinding.make(
            app: app,
            service_instance: instance
          )
          app.add_service_binding(binding)
        end
      end
    end

    let(:dea_id) { 'dea_123' }
    let(:dea_ad) { create_ad(dea_id) }
    let(:abc_ad) { create_ad('abc') }
    let(:def_ad) { create_ad('def', 'https://host:1234') }

    let(:blobstore_url_generator) do
      double('blobstore_url_generator', droplet_download_url: 'app_uri')
    end

    let(:http_overrides) do
      {
        dea_client: {
          key_file: File.join(Paths::FIXTURES, 'certs/dea_client.key'),
          cert_file: File.join(Paths::FIXTURES, 'certs/dea_client.crt'),
          ca_file: File.join(Paths::FIXTURES, 'certs/dea_ca.crt'),
        }
      }
    end
    let(:overrides) { {} }

    def create_ad(id, url=nil)
      hash = { 'id' => id }
      hash['url'] = url if url
      Dea::NatsMessages::DeaAdvertisement.new(hash, nil)
    end

    before do
      TestConfig.override(overrides)

      Dea::Client.configure(TestConfig.config, message_bus, dea_pool, blobstore_url_generator)
    end

    describe '#enabled?' do
      it 'returns false by default' do
        expect(Dea::Client.enabled?).to be_falsey
      end

      context 'when configured for http' do
        let(:overrides) { http_overrides }

        it 'returns true' do
          expect(Dea::Client.enabled?).to be_truthy
        end
      end
    end

    describe '.run' do
      it 'registers subscriptions for dea_pool' do
        expect(dea_pool).to receive(:register_subscriptions)
        described_class.run
      end
    end

    describe 'update_uris' do
      it "does not update deas if app isn't staged" do
        app.update(package_state: 'PENDING')
        expect(message_bus).not_to receive(:publish)
        Dea::Client.update_uris(app)
      end

      it 'sends a dea update message' do
        app.update(package_state: 'STAGED')
        expect(message_bus).to receive(:publish).with(
          'dea.update',
          hash_including(
            # XXX: change this to actual URLs from user once we do it
            uris: kind_of(Array),
            version: app.version
          )
        )
        Dea::Client.update_uris(app)
      end
    end

    describe 'start_instances' do
      it 'should send start messages' do
        app.instances = 3

        expect(dea_pool).to receive(:find_dea).twice.and_return(dea_ad)
        expect(dea_pool).to receive(:mark_app_started).twice.with(dea_id: dea_id, app_id: app.guid)
        expect(dea_pool).to receive(:reserve_app_memory).twice.with(dea_id, app.memory)
        expect(message_bus).to receive(:publish).with(
          'dea.dea_123.start',
          hash_including(
            index: 1,
          )
        ).ordered

        expect(message_bus).to receive(:publish).with(
          'dea.dea_123.start',
          hash_including(
            index: 2,
          )
        ).ordered

        Dea::Client.start_instances(app, [1, 2])
      end

      context 'when the DEAs have insufficient capacity to start all the indices' do
        it 'attempts to find DEAs for all indices and raises an InsufficientRunningResourcesAvailable error' do
          app.instances = 4
          expect(dea_pool).to receive(:find_dea).and_return(nil, nil, dea_ad)
          expect(dea_pool).to receive(:mark_app_started).once.with(dea_id: dea_id, app_id: app.guid)
          expect(dea_pool).to receive(:reserve_app_memory).once.with(dea_id, app.memory)

          expect(message_bus).to receive(:publish).once.with(
            'dea.dea_123.start',
            hash_including(
              index: 3,
            )
          )

          expect {
            Dea::Client.start_instances(app, [1, 2, 3])
          }.to raise_error CloudController::Errors::ApiError, 'One or more instances could not be started because of insufficient running resources.'
        end
      end

      context 'when droplet is missing' do
        let(:blobstore_url_generator) do
          double('blobstore_url_generator', droplet_download_url: nil)
        end

        it 'should raise an error if the droplet is missing' do
          expect {
            Dea::Client.start_instances(app, 1)
          }.to raise_error CloudController::Errors::ApiError, "The app package could not be found: #{app.guid}"
        end
      end

      context 'when no DEA is available' do
        it 'raises a InsufficientRunningResourcesAvailable error and logs without passwords' do
          logger = double(Steno)
          allow(Dea::Client).to receive(:logger).and_return(logger)

          expect(dea_pool).to receive(:find_dea).once.and_return(nil)
          expect(logger).to receive(:error) { |msg, data|
            expect(data[:message]).not_to include(:services, :env, :executableUri)
          }.once

          expect {
            Dea::Client.start_instances(app, 1)
          }.to raise_error CloudController::Errors::ApiError, 'One or more instances could not be started because of insufficient running resources.'
        end
      end

      context 'callbacks' do
        it 'skips nil callbacks' do
          app.instances = 1

          expect(Dea::Client).to receive(:start_instance_at_index).with(app, 1).and_return(nil)

          expect { Dea::Client.start_instances(app, 1) }.to_not raise_error
        end

        it 'calls the callback' do
          app.instances = 2

          count = 0
          cb = lambda { count += 1 }
          expect(Dea::Client).to receive(:start_instance_at_index).and_return(cb).twice

          expect { Dea::Client.start_instances(app, [1, 2]) }.to_not raise_error
          expect(count).to eq(2)
        end

        context 'when an error is raised' do
          it 'calls all callbacks' do
            app.instances = 2

            count = 0
            cb = lambda { count += 1 }
            expect(Dea::Client).to receive(:start_instance_at_index).and_return(cb)
            expect(Dea::Client).to receive(:start_instance_at_index).and_raise('bogus')

            expect { Dea::Client.start_instances(app, [1, 2]) }.to raise_error 'bogus'
            expect(count).to eq(1)
          end
        end

        context 'when starting more than 5 instances' do
          it 'should start 5 at a time' do
            app.instances = 9

            count = 0
            cb5 = lambda { expect(count).to eq 5 }
            cb9 = lambda { expect(count).to eq 9 }
            allow(Dea::Client).to receive(:start_instance_at_index) do
              count += 1
              count <= 5 ? cb5 : cb9
            end

            Dea::Client.start_instances(app, 1..9)
          end
        end
      end
    end

    describe '#stage' do
      let(:stager_url) { 'https://host:1234' }
      let(:staging_msg) { 'staging message' }
      let(:overrides) { http_overrides }
      let(:post_url) { "#{stager_url}/v1/stage" }

      it 'sends a stage message to the dea' do
        stub_request(:post, post_url).with(body: /#{staging_msg}/, headers: { 'Content-Type' => 'application/json' }).to_return(status: [202, 'Accepted'])
        expect(Dea::Client.stage(stager_url, staging_msg)).to be_truthy
      end

      context 'when an error occurs' do
        context 'when we get a status of 404' do
          it 'returns false' do
            stub_request(:post, post_url).with(body: /#{staging_msg}/, headers: { 'Content-Type' => 'application/json' }).to_return(status: [404, 'Not Found'])
            expect(Dea::Client.stage(stager_url, staging_msg)).to be_falsey
          end
        end

        context 'when we get a status other than 202 or 404' do
          it 'raises an error' do
            stub_request(:post, post_url).with(body: /#{staging_msg}/, headers: { 'Content-Type' => 'application/json' }).to_return(status: [500, 'Internal Server Error'])
            expect { Dea::Client.stage(stager_url, staging_msg) }.to raise_error CloudController::Errors::ApiError, /received 500 from #{post_url}/
          end
        end

        context 'when an exception occurs' do
          it 'raises an appropriate error' do
            stub_request(:post, post_url).with(body: /#{staging_msg}/, headers: { 'Content-Type' => 'application/json' }).to_raise 'failed to connect'
            expect { Dea::Client.stage(stager_url, staging_msg) }.to raise_error CloudController::Errors::ApiError, /#{stager_url}.*failed to connect/
          end
        end
      end

      context 'when not configured for HTTP' do
        before do
          allow(Dea::Client).to receive(:enabled?).and_return(false)
        end
        it 'raises an error' do
          expect { Dea::Client.stage(stager_url, staging_msg) }.to raise_error { |error|
            expect(error).to be_an_instance_of(CloudController::Errors::ApiError)
            expect(error.name).to eq('StagerError')
            expect(error.message).to eq('Stager error: Client not HTTP enabled')
          }
        end
      end
    end

    describe 'start' do
      it 'should send start messages to deas' do
        app.instances = 2
        expect(dea_pool).to receive(:find_dea).and_return(abc_ad, def_ad)
        expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'abc', app_id: app.guid)
        expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'def', app_id: app.guid)
        expect(dea_pool).to receive(:reserve_app_memory).with('abc', app.memory)
        expect(dea_pool).to receive(:reserve_app_memory).with('def', app.memory)
        expect(message_bus).to receive(:publish).with('dea.abc.start', kind_of(Hash))
        expect(message_bus).to receive(:publish).with('dea.def.start', kind_of(Hash))

        Dea::Client.start(app)
      end

      it 'should start the specified number of instances' do
        app.instances = 2
        allow(dea_pool).to receive(:find_dea).and_return(abc_ad, def_ad)

        expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'abc', app_id: app.guid)
        expect(dea_pool).not_to receive(:mark_app_started).with(dea_id: 'def', app_id: app.guid)
        expect(dea_pool).to receive(:reserve_app_memory).with('abc', app.memory)
        expect(dea_pool).not_to receive(:reserve_app_memory).with('def', app.memory)

        Dea::Client.start(app, instances_to_start: 1)
      end

      context 'with a cc_partition' do
        let(:overrides) { { cc_partition: 'ngFTW' } }

        it 'sends a dea start message that includes cc_partition' do
          app.instances = 1
          expect(dea_pool).to receive(:find_dea).and_return(abc_ad)
          expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'abc', app_id: app.guid)
          expect(dea_pool).to receive(:reserve_app_memory).with('abc', app.memory)
          expect(message_bus).to receive(:publish).with('dea.abc.start', hash_including(cc_partition: 'ngFTW'))

          Dea::Client.start(app)
        end
      end

      it 'includes memory in find_dea request' do
        app.instances = 1
        app.memory = 512
        expect(dea_pool).to receive(:find_dea).with(include(mem: 512)).and_return(abc_ad)
        expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'abc', app_id: app.guid)
        expect(dea_pool).to receive(:reserve_app_memory).with('abc', app.memory)
        Dea::Client.start(app)
      end

      it 'includes disk in find_dea request' do
        app.instances = 1
        app.disk_quota = 13
        expect(dea_pool).to receive(:find_dea).with(include(disk: 13)).and_return(abc_ad)
        expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'abc', app_id: app.guid)
        expect(dea_pool).to receive(:reserve_app_memory).with('abc', app.memory)
        Dea::Client.start(app)
      end

      context 'when http is enabled' do
        let(:overrides) { http_overrides }

        it 'should send start messages to deas' do
          app.instances = 2
          expect(dea_pool).to receive(:find_dea).and_return(abc_ad, def_ad)
          expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'abc', app_id: app.guid)
          expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'def', app_id: app.guid)
          expect(dea_pool).to receive(:reserve_app_memory).with('abc', app.memory)
          expect(dea_pool).to receive(:reserve_app_memory).with('def', app.memory)
          expect(message_bus).to receive(:publish).with('dea.abc.start', kind_of(Hash))
          expect(message_bus).to_not receive(:publish).with('dea.def.start', kind_of(Hash))
          stub_request(:post, 'https://host:1234/v1/apps').with(body: /\{.*\}/, headers: { 'Content-Type' => 'application/json' })

          Dea::Client.start(app)
        end

        context 'when an error occurs over http' do
          it 'is ignored' do
            logger = double(Steno::Logger, debug: nil)
            allow(Dea::Client).to receive(:logger).and_return(logger)
            expect(logger).to receive(:warn).with('start failed', include(:dea_id, :url, :error))

            app.instances = 1
            expect(dea_pool).to receive(:find_dea).and_return(def_ad)
            expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'def', app_id: app.guid)
            expect(dea_pool).to receive(:reserve_app_memory).with('def', app.memory)
            expect(message_bus).to_not receive(:publish).with('dea.def.start', kind_of(Hash))
            stub_request(:post, 'https://host:1234/v1/apps').to_raise(::HTTPClient::TimeoutError)

            expect { Dea::Client.start(app) }.to_not raise_error
          end
        end
      end
    end

    describe 'stop_indices' do
      it 'should send stop messages to deas' do
        app.instances = 3
        expect(message_bus).to receive(:publish).with(
          'dea.stop',
          hash_including(
            droplet: app.guid,
            indices: [0, 2],
          )
        )

        Dea::Client.stop_indices(app, [0, 2])
      end
    end

    describe 'stop_instances' do
      it 'should send stop messages to deas' do
        app.instances = 3
        expect(message_bus).to receive(:publish).with(
          'dea.stop',
          hash_including(
            droplet: app.guid,
            instances: ['a', 'b']
          )
        ) do |_, payload|
          expect(payload).to_not include(:version)
        end

        Dea::Client.stop_instances(app.guid, ['a', 'b'])
      end

      it 'should support single instance' do
        expect(message_bus).to receive(:publish).with(
          'dea.stop',
          hash_including(droplet: app.guid, instances: ['a'])
        ) do |_, payload|
          expect(payload).to_not include(:version)
        end

        Dea::Client.stop_instances(app.guid, 'a')
      end
    end

    describe 'find_specific_instance' do
      it 'should find a specific instance' do
        expect(app).to receive(:guid).and_return(1)

        encoded = { droplet: 1, other_opt: 'value' }
        expect(message_bus).to receive(:synchronous_request).
          with('dea.find.droplet', encoded, { timeout: 2 }).
          and_return(['instance'])

        expect(Dea::Client.find_specific_instance(app, { other_opt: 'value' })).to eq('instance')
      end
    end

    describe 'find_instances' do
      it 'should use specified message options' do
        expect(app).to receive(:guid).and_return(1)
        expect(app).to receive(:instances).and_return(2)

        instance_json = 'instance'
        encoded = {
          droplet: 1,
          other_opt_0: 'value_0',
          other_opt_1: 'value_1',
        }
        expect(message_bus).to receive(:synchronous_request).
          with('dea.find.droplet', encoded, { result_count: 2, timeout: 2 }).
          and_return([instance_json, instance_json])

        message_options = {
          other_opt_0: 'value_0',
          other_opt_1: 'value_1',
        }

        expect(Dea::Client.find_instances(app, message_options)).to eq(['instance', 'instance'])
      end

      it 'should use default values for expected instances and timeout if none are specified' do
        expect(app).to receive(:guid).and_return(1)
        expect(app).to receive(:instances).and_return(2)

        instance_json = 'instance'
        encoded = { droplet: 1 }
        expect(message_bus).to receive(:synchronous_request).
          with('dea.find.droplet', encoded, { result_count: 2, timeout: 2 }).
          and_return([instance_json, instance_json])

        expect(Dea::Client.find_instances(app)).to eq(['instance', 'instance'])
      end

      it 'should use the specified values for expected instances and timeout' do
        expect(app).to receive(:guid).and_return(1)

        instance_json = 'instance'
        encoded = { droplet: 1, other_opt: 'value' }
        expect(message_bus).to receive(:synchronous_request).
          with('dea.find.droplet', encoded, { result_count: 5, timeout: 10 }).
          and_return([instance_json, instance_json])

        expect(Dea::Client.find_instances(app, { other_opt: 'value' },
                                   { result_count: 5, timeout: 10 })).
          to eq(['instance', 'instance'])
      end
    end

    describe 'get_file_uri_for_instance' do
      include Errors

      it 'should raise an error if the app is in stopped state' do
        expect(app).to receive(:stopped?).once.and_return(true)
        allow(app).to receive(:instances) { 1 }

        instance = 0
        path = 'test'

        expect {
          Dea::Client.get_file_uri_for_active_instance_by_index(app, path, instance)
        }.to raise_error CloudController::Errors::ApiError, "File error: Request failed for app: #{app.name} path: #{path} as the app is in stopped state."
      end

      it 'should raise an error if the instance is out of range' do
        app.instances = 5

        instance = 10
        path = 'test'

        expect {
          Dea::Client.get_file_uri_for_active_instance_by_index(app, path, instance)
        }.to raise_error { |error|
          expect(error).to be_an_instance_of CloudController::Errors::ApiError
          expect(error.name).to eq('FileError')

          msg = "File error: Request failed for app: #{app.name}"
          msg << ", instance: #{instance} and path: #{path} as the instance is"
          msg << ' out of range.'

          expect(error.message).to eq(msg)
        }
      end

      it 'should return the file uri if the required instance is found via DEA v1' do
        app.instances = 2
        expect(app).to receive(:stopped?).once.and_return(false)

        instance = 1
        path = 'test'

        search_options = {
          indices: [instance],
          states: Dea::Client::ACTIVE_APP_STATES,
          version: app.version,
          path: 'test',
          droplet: app.guid
        }

        instance_found = {
          'file_uri' => 'http://1.2.3.4/',
          'staged' => 'staged',
          'credentials' => ['username', 'password'],
        }

        message_bus.respond_to_synchronous_request('dea.find.droplet', [instance_found])

        result = Dea::Client.get_file_uri_for_active_instance_by_index(app, path, instance)
        expect(result.file_uri_v1).to eq('http://1.2.3.4/staged/test')
        expect(result.file_uri_v2).to be_nil
        expect(result.credentials).to eq(['username', 'password'])

        expect(message_bus).to have_requested_synchronous_messages('dea.find.droplet', search_options, { timeout: 2 })
      end

      it 'should return both file_uri_v2 and file_uri_v1 from DEA v2' do
        app.instances = 2
        expect(app).to receive(:stopped?).once.and_return(false)

        instance = 1
        path = 'test'

        search_options = {
          indices: [instance],
          states: Dea::Client::ACTIVE_APP_STATES,
          version: app.version,
          path: 'test',
          droplet: app.guid
        }

        instance_found = {
          'file_uri_v2' => 'file_uri_v2',
          'file_uri' => 'http://1.2.3.4/',
          'staged' => 'staged',
          'credentials' => ['username', 'password'],
        }

        message_bus.respond_to_synchronous_request('dea.find.droplet', [instance_found])

        info = Dea::Client.get_file_uri_for_active_instance_by_index(app, path, instance)
        expect(info.file_uri_v2).to eq('file_uri_v2')
        expect(info.file_uri_v1).to eq('http://1.2.3.4/staged/test')
        expect(info.credentials).to eq(['username', 'password'])

        expect(message_bus).to have_requested_synchronous_messages('dea.find.droplet', search_options, { timeout: 2 })
      end

      it 'should raise an error if the instance is not found' do
        app.instances = 2
        expect(app).to receive(:stopped?).once.and_return(false)

        instance = 1
        path = 'test'
        msg = "File error: Request failed for app: #{app.name}"
        msg << ", instance: #{instance} and path: #{path} as the instance is"
        msg << ' not found.'

        search_options = {
          indices: [instance],
          states: Dea::Client::ACTIVE_APP_STATES,
          version: app.version,
          path: 'test',
          droplet: app.guid
        }

        message_bus.respond_to_synchronous_request('dea.find.droplet', [])

        expect {
          Dea::Client.get_file_uri_for_active_instance_by_index(app, path, instance)
        }.to raise_error CloudController::Errors::ApiError, msg

        expect(message_bus).to have_requested_synchronous_messages('dea.find.droplet', search_options, { timeout: 2 })
      end
    end

    describe 'get_file_uri_for_instance_id' do
      include Errors

      it 'should raise an error if the app is in stopped state' do
        expect(app).to receive(:stopped?).once.and_return(true)

        instance_id = 'abcdef'
        path = 'test'
        msg = "File error: Request failed for app: #{app.name}"
        msg << " path: #{path} as the app is in stopped state."

        expect {
          Dea::Client.get_file_uri_by_instance_guid(app, path, instance_id)
        }.to raise_error CloudController::Errors::ApiError, msg
      end

      it 'should return the file uri if the required instance is found via DEA v1' do
        app.instances = 2
        expect(app).to receive(:stopped?).once.and_return(false)

        instance_id = 'abcdef'
        path = 'test'

        search_options = {
          instance_ids: [instance_id],
          states: [:STARTING, :RUNNING, :CRASHED],
          path: 'test',
          droplet: app.guid
        }

        instance_found = {
          'file_uri' => 'http://1.2.3.4/',
          'staged' => 'staged',
          'credentials' => ['username', 'password'],
        }

        message_bus.respond_to_synchronous_request('dea.find.droplet', [instance_found])

        result = Dea::Client.get_file_uri_by_instance_guid(app, path, instance_id)
        expect(result.file_uri_v1).to eq('http://1.2.3.4/staged/test')
        expect(result.file_uri_v2).to be_nil
        expect(result.credentials).to eq(['username', 'password'])

        expect(message_bus).to have_requested_synchronous_messages('dea.find.droplet', search_options, { timeout: 2 })
      end

      it 'should return both file_uri_v2 and file_uri_v1 from DEA v2' do
        app.instances = 2
        expect(app).to receive(:stopped?).once.and_return(false)

        instance_id = 'abcdef'
        path = 'test'

        search_options = {
          instance_ids: [instance_id],
          states: [:STARTING, :RUNNING, :CRASHED],
          path: 'test',
          droplet: app.guid
        }

        instance_found = {
          'file_uri_v2' => 'file_uri_v2',
          'file_uri' => 'http://1.2.3.4/',
          'staged' => 'staged',
          'credentials' => ['username', 'password'],
        }

        message_bus.respond_to_synchronous_request('dea.find.droplet', [instance_found])

        info = Dea::Client.get_file_uri_by_instance_guid(app, path, instance_id)
        expect(info.file_uri_v2).to eq('file_uri_v2')
        expect(info.file_uri_v1).to eq('http://1.2.3.4/staged/test')
        expect(info.credentials).to eq(['username', 'password'])

        expect(message_bus).to have_requested_synchronous_messages('dea.find.droplet', search_options, { timeout: 2 })
      end

      it 'should raise an error if the instance_id is not found' do
        app.instances = 2
        expect(app).to receive(:stopped?).once.and_return(false)

        instance_id = 'abcdef'
        path = 'test'

        search_options = {
          instance_ids: [instance_id],
          states: [:STARTING, :RUNNING, :CRASHED],
          path: 'test',
        }

        expect(Dea::Client).to receive(:find_specific_instance).
          with(app, search_options).and_return(nil)

        expect {
          Dea::Client.get_file_uri_by_instance_guid(app, path, instance_id)
        }.to raise_error { |error|
          expect(error).to be_an_instance_of CloudController::Errors::ApiError
          expect(error.name).to eq('FileError')

          msg = "File error: Request failed for app: #{app.name}"
          msg << ", instance_id: #{instance_id} and path: #{path} as the instance_id is"
          msg << ' not found.'

          expect(error.message).to eq(msg)
        }
      end
    end

    describe 'find_stats' do
      it 'should return the stats for all instances' do
        app.instances = 2

        stats = double('mock stats')
        instance_0 = {
          'index' => 0,
          'state' => 'RUNNING',
          'stats' => stats,
        }

        instance_1 = {
          'index' => 1,
          'state' => 'RUNNING',
          'stats' => stats,
        }

        message_bus.respond_to_synchronous_request('dea.find.droplet', [instance_0, instance_1])

        app_stats = Dea::Client.find_stats(app)
        expect(app_stats).to eq(
          0 => {
            state: 'RUNNING',
            stats: stats,
          },
          1 => {
            state: 'RUNNING',
            stats: stats,
          }
        )
      end

      it 'should return filler stats for instances that have not responded' do
        app.instances = 2

        search_options = {
          include_stats: true,
          states: [:RUNNING],
          version: app.version,
          droplet: app.guid
        }

        stats = double('mock stats')
        instance = {
          'index' => 0,
          'state' => 'RUNNING',
          'stats' => stats,
        }

        allow(Time).to receive(:now) { double(:utc_time, to_f: 1.0, utc: 1) }

        message_bus.respond_to_synchronous_request('dea.find.droplet', [instance])

        app_stats = Dea::Client.find_stats(app)

        expect(app_stats).to eq(
          0 => {
            state: 'RUNNING',
            stats: stats,
          },
          1 => {
            state: 'DOWN',
            since: 1,
          }
        )

        expect(message_bus).to have_requested_synchronous_messages('dea.find.droplet', search_options, { result_count: 2, timeout: 2 })
      end

      it 'should return filler stats for instances with out of range indices' do
        app.instances = 2

        search_options = {
          include_stats: true,
          states: [:RUNNING],
          version: app.version,
          droplet: app.guid
        }

        stats = double('mock stats')
        instance_0 = {
          'index' => -1,
          'state' => 'RUNNING',
          'stats' => stats,
        }

        instance_1 = {
          'index' => 0,
          'state' => 'RUNNING',
          'stats' => stats,
        }

        instance_2 = {
          'index' => 2,
          'state' => 'RUNNING',
          'stats' => stats,
        }

        allow(Time).to receive(:now) { double(:utc_time, to_f: 1.0, utc: 1) }

        message_bus.respond_to_synchronous_request('dea.find.droplet', [instance_0, instance_1, instance_2])

        app_stats = Dea::Client.find_stats(app)
        expect(app_stats).to eq(
          0 => {
            state: 'RUNNING',
            stats: stats,
          },
          1 => {
            state: 'DOWN',
            since: 1,
          }
        )

        expect(message_bus).to have_requested_synchronous_messages('dea.find.droplet', search_options, { result_count: 2, timeout: 2 })
      end
    end

    describe 'find_all_instances' do
      let!(:health_manager_client) do
        CloudController::DependencyLocator.instance.health_manager_client.tap do |hm|
          allow(VCAP::CloudController::Dea::Client).to receive(:health_manager_client) { hm }
        end
      end

      include Errors

      it 'should return starting or running instances' do
        app.instances = 3

        flapping_instances = [
          { 'index' => 0, 'since' => 1 },
        ]

        expect(health_manager_client).to receive(:find_flapping_indices).
          with(app).and_return(flapping_instances)

        search_options = {
          states: [:STARTING, :RUNNING],
          version: app.version,
        }

        starting_instance = {
          'index' => 1,
          'state' => 'STARTING',
          'state_timestamp' => 2,
          'debug_ip' => '1.2.3.4',
          'debug_port' => 1001,
          'console_ip' => '1.2.3.5',
          'console_port' => 1002,
        }

        running_instance = {
          'index' => 2,
          'state' => 'RUNNING',
          'state_timestamp' => 3,
          'debug_ip' => '2.3.4.5',
          'debug_port' => 2001,
          'console_ip' => '2.3.4.6',
          'console_port' => 2002,
        }

        expect(Dea::Client).to receive(:find_instances).
          with(app, search_options, { expected: 2 }).
          and_return([starting_instance, running_instance])

        app_instances = Dea::Client.find_all_instances(app)
        expect(app_instances).to eq({
          0 => {
            state: 'FLAPPING',
            since: 1,
          },
          1 => {
            state: 'STARTING',
            since: 2,
            debug_ip: '1.2.3.4',
            debug_port: 1001,
            console_ip: '1.2.3.5',
            console_port: 1002,
          },
          2 => {
            state: 'RUNNING',
            since: 3,
            debug_ip: '2.3.4.5',
            debug_port: 2001,
            console_ip: '2.3.4.6',
            console_port: 2002,
          },
        })
      end

      it 'should ignore out of range indices of starting or running instances' do
        app.instances = 2

        expect(health_manager_client).to receive(:find_flapping_indices).
          with(app).and_return([])

        search_options = {
          states: [:STARTING, :RUNNING],
          version: app.version,
        }

        starting_instance = {
          'index' => -1, # -1 is out of range.
          'state_timestamp' => 1,
          'debug_ip' => '1.2.3.4',
          'debug_port' => 1001,
          'console_ip' => '1.2.3.5',
          'console_port' => 1002,
        }

        running_instance = {
          'index' => 2, # 2 is out of range.
          'state' => 'RUNNING',
          'state_timestamp' => 2,
          'debug_ip' => '2.3.4.5',
          'debug_port' => 2001,
          'console_ip' => '2.3.4.6',
          'console_port' => 2002,
        }

        expect(Dea::Client).to receive(:find_instances).
          with(app, search_options, { expected: 2 }).
          and_return([starting_instance, running_instance])

        allow(Time).to receive(:now) { double(:utc_time, to_f: 1.0, utc: 1) }

        app_instances = Dea::Client.find_all_instances(app)
        expect(app_instances).to eq({
          0 => {
            state: 'DOWN',
            since: 1,
          },
          1 => {
            state: 'DOWN',
            since: 1,
          },
        })
      end

      it 'should return fillers for instances that have not responded' do
        app.instances = 2

        expect(health_manager_client).to receive(:find_flapping_indices).
          with(app).and_return([])

        search_options = {
          states: [:STARTING, :RUNNING],
          version: app.version,
        }

        expect(Dea::Client).to receive(:find_instances).
          with(app, search_options, { expected: 2 }).
          and_return([])

        allow(Time).to receive(:now) { double(:utc_time, to_f: 1.0, utc: 1) }

        app_instances = Dea::Client.find_all_instances(app)
        expect(app_instances).to eq({
          0 => {
            state: 'DOWN',
            since: 1,
          },
          1 => {
            state: 'DOWN',
            since: 1,
          },
        })
      end
    end

    describe 'change_running_instances' do
      context 'increasing the instance count' do
        let(:efg_ad) { create_ad('efg') }

        it 'should issue a start command with extra indices' do
          expect(dea_pool).to receive(:find_dea).and_return(abc_ad)
          expect(dea_pool).to receive(:find_dea).and_return(def_ad)
          expect(dea_pool).to receive(:find_dea).and_return(efg_ad)
          expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'abc', app_id: app.guid)
          expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'def', app_id: app.guid)
          expect(dea_pool).to receive(:mark_app_started).with(dea_id: 'efg', app_id: app.guid)

          expect(dea_pool).to receive(:reserve_app_memory).with('abc', app.memory)
          expect(dea_pool).to receive(:reserve_app_memory).with('def', app.memory)
          expect(dea_pool).to receive(:reserve_app_memory).with('efg', app.memory)

          expect(message_bus).to receive(:publish).with('dea.abc.start', kind_of(Hash))
          expect(message_bus).to receive(:publish).with('dea.efg.start', kind_of(Hash))
          expect(message_bus).to receive(:publish).with('dea.def.start', kind_of(Hash))

          app.instances = 4
          app.save

          Dea::Client.change_running_instances(app, 3)
        end
      end

      context 'decreasing the instance count' do
        it 'should stop the higher indices' do
          expect(message_bus).to receive(:publish).with('dea.stop', kind_of(Hash))
          app.instances = 5
          app.save

          Dea::Client.change_running_instances(app, -2)
        end
      end

      context 'with no changes' do
        it 'should do nothing' do
          app.instances = 9
          app.save

          Dea::Client.change_running_instances(app, 0)
        end
      end
    end
  end
end
