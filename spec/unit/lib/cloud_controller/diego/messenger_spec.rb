require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe Messenger do
      let(:message_bus) { CfMessageBus::MockMessageBus.new }

      let(:domain) { SharedDomain.make(name: 'some-domain.com') }
      let(:route1) { Route.make(host: 'some-route', domain: domain) }
      let(:route2) { Route.make(host: 'some-other-route', domain: domain) }

      let(:app) do
        app = AppFactory.make
        app.instances = 3
        app.health_check_timeout = 120
        app
      end

      let(:blobstore_url_generator) do
        double('blobstore_url_generator',
          perma_droplet_download_url: 'app_uri',
          buildpack_cache_download_url: 'http://buildpack-artifacts-cache.com',
          app_package_download_url: 'http://app-package.com',
          admin_buildpack_download_url: 'https://example.com',
          buildpack_cache_upload_url: 'http://buildpack-artifacts-cache.up.com',
          droplet_upload_url: 'http://droplet-upload-uri',
        )
      end

      let(:protocol) do
        Traditional::Protocol.new(blobstore_url_generator, Common::Protocol.new)
      end

      subject(:messenger) { Messenger.new(message_bus, protocol) }

      describe 'staging an app' do
        it 'sends a nats message with the appropriate staging subject and payload' do
          messenger.send_stage_request(app, 90)

          expected_message = {
            'app_id' => app.guid,
            'task_id' => app.staging_task_id,
            'memory_mb' => app.memory,
            'disk_mb' => app.disk_quota,
            'file_descriptors' => app.file_descriptors,
            'environment' => Environment.new(app).as_json,
            'stack' => app.stack.name,
            'build_artifacts_cache_download_uri' => 'http://buildpack-artifacts-cache.com',
            'build_artifacts_cache_upload_uri' => 'http://buildpack-artifacts-cache.up.com',
            'app_bits_download_uri' => 'http://app-package.com',
            'buildpacks' => Traditional::BuildpackEntryGenerator.new(blobstore_url_generator).buildpack_entries(app),
            'droplet_upload_uri' => 'http://droplet-upload-uri',
            'egress_rules' => [],
            'timeout' => 90,
          }

          expect(message_bus.published_messages.size).to eq(1)
          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq('diego.staging.start')
          expect(nats_message[:message]).to match_json(expected_message)
        end
      end

      describe 'desiring an app' do
        let(:expected_message) do
          {
            'process_guid' => "#{app.guid}-#{app.version}",
            'memory_mb' => app.memory,
            'disk_mb' => app.disk_quota,
            'file_descriptors' => app.file_descriptors,
            'droplet_uri' => 'app_uri',
            'stack' => app.stack.name,
            'start_command' => app.command,
            'execution_metadata' => 'the-staging-metadata',
            'environment' => Environment.new(app).as_json,
            'num_instances' => expected_instances,
            'routes' => [],
            'health_check_type' => app.health_check_type,
            'health_check_timeout_in_seconds' => 120,
            'log_guid' => app.guid,
            'egress_rules' => [],
            'etag' => app.updated_at.to_f.to_s,
          }
        end

        let(:expected_instances) { 3 }

        before do
          app.command = './the-custom-command'
          app.add_new_droplet('lol')
          app.current_droplet.update_execution_metadata('the-staging-metadata')
          app.state = 'STARTED'
        end

        it 'sends a nats message with the appropriate subject and payload' do
          messenger.send_desire_request(app)

          expect(message_bus.published_messages.size).to eq(1)
          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq('diego.desire.app')
          expect(nats_message[:message]).to match_json(expected_message)
        end

        context 'when the app is not started' do
          let(:expected_instances) { 0 }

          before do
            app.state = 'STOPPED'
          end

          it 'should desire 0 instances' do
            messenger.send_desire_request(app)

            nats_message = message_bus.published_messages.first
            expect(nats_message[:subject]).to eq('diego.desire.app')
            expect(nats_message[:message]).to match_json(expected_message)
          end
        end

        context 'when the app has routes' do
          before do
            app.space.add_route(route1)
            app.space.add_route(route2)
            app.add_route(route1)
            app.add_route(route2)
          end

          it "should desire it with the correct 'routes'" do
            messenger.send_desire_request(app)

            expected_message['routes'] = ['some-route.some-domain.com', 'some-other-route.some-domain.com']

            nats_message = message_bus.published_messages.first
            expect(nats_message[:subject]).to eq('diego.desire.app')
            expect(nats_message[:message]).to match_json(expected_message)
          end
        end
      end

      describe 'stop staging an app' do
        let(:task_id) { 'staging_task_id' }

        it 'sends a stop staging request' do
          messenger.send_stop_staging_request(app, task_id)

          expected_message = {
            'app_id' => app.guid,
            'task_id' => task_id,
          }

          expect(message_bus.published_messages.size).to eq(1)
          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq('diego.staging.stop')
          expect(nats_message[:message]).to match_json(expected_message)
        end
      end
    end
  end
end
