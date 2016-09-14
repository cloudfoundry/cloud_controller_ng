require 'spec_helper'

module VCAP::CloudController
  module Dea
    RSpec.describe Stager do
      subject(:stager) { Stager.new(app, config, message_bus, dea_pool, runners) }
      let(:config) { instance_double(Config) }
      let(:message_bus) { instance_double(CfMessageBus::MessageBus, publish: nil) }
      let(:dea_pool) { instance_double(Dea::Pool) }
      let(:runners) { instance_double(Runners) }
      let(:runner) { double(:Runner) }
      let(:stager_task) { instance_double(AppStagerTask) }
      let(:staging_details) { instance_double(Diego::StagingDetails, droplet: process.latest_droplet) }

      let(:reply_json_error) { nil }
      let(:reply_error_info) { nil }
      let(:detected_buildpack) { nil }
      let(:detected_start_command) { 'wait_for_godot' }
      let(:buildpack_key) { nil }
      let(:droplet_hash) { 'droplet-sha1' }
      let(:reply_json) do
        {
          'task_id' => 'task-id',
          'task_log' => 'task-log',
          'task_streaming_log_url' => nil,
          'detected_buildpack' => detected_buildpack,
          'buildpack_key' => buildpack_key,
          'procfile' => { 'web' => "while true; do { echo -e 'HTTP/1.1 200 OK\\r\\n'; echo custom buildpack contents - cache not found; } | nc -l $PORT; done" },
          'detected_start_command' => detected_start_command,
          'error' => reply_json_error,
          'error_info' => reply_error_info,
          'droplet_sha1' => droplet_hash,
        }
      end
      let(:staging_result) { StagingResponse.new(reply_json) }
      let(:staging_error) { nil }

      let(:response) { reply_json }

      let(:app) { AppModel.make }
      let(:process) { AppFactory.make(app: app, type: 'web') }

      it_behaves_like 'a stager'

      describe '#stage' do
        before do
          allow(AppStagerTask).to receive(:new).and_return(stager_task)
          allow(stager_task).to receive(:stage).and_yield('fake-staging-result').and_return('fake-stager-response')
          allow(runners).to receive(:runner_for_app).with(process).and_return(runner)
          allow(runner).to receive(:start).with('fake-staging-result')
        end

        it 'stages the app with a stager task' do
          stager.stage(staging_details)
          expect(stager_task).to have_received(:stage)
          expect(AppStagerTask).to have_received(:new).with(config,
                                                            message_bus,
                                                            process.latest_droplet,
                                                            dea_pool,
                                                            an_instance_of(CloudController::Blobstore::UrlGenerator))
        end

        it 'starts the app with the returned staging result' do
          stager.stage(staging_details)
          expect(runner).to have_received(:start).with('fake-staging-result')
        end
      end

      describe '#staging_complete' do
        before do
          allow(AppStagerTask).to receive(:new).and_return(stager_task)
        end

        it 'invokes AppStagerTask#handle_http_response for response handling' do
          expect(stager_task).to receive(:handle_http_response).with(response)
          stager.staging_complete(nil, response)
        end

        context 'when the callback is invoked' do
          before do
            allow(stager_task).to receive(:handle_http_response).and_yield('fake-staging-result').and_return('fake-stager-response')
            allow(runners).to receive(:runner_for_app).with(process).and_return(runner)
            allow(runner).to receive(:start).with('fake-staging-result')
          end

          it 'starts the app with the returned staging result' do
            expect(runner).to receive(:start).with('fake-staging-result')
            stager.staging_complete(nil, response)
          end
        end
      end
    end
  end
end
