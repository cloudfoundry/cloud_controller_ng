require 'spec_helper'
require 'cloud_controller/diego/task_protocol'

module VCAP::CloudController::Diego
  RSpec.describe NsyncClient do
    let(:content_type_header) { { 'Content-Type' => 'application/json' } }
    let(:process) { VCAP::CloudController::ProcessModelFactory.make }
    let(:process_guid) { ProcessGuid.from_process(process) }
    let(:desire_message) { MultiJson.dump({ process_guid: process_guid }) }
    let(:config) { TestConfig.config_instance }

    subject(:client) { NsyncClient.new(config) }

    describe '#desire_app' do
      let(:desire_app_url) { "#{TestConfig.config[:diego][:nsync_url]}/v1/apps/#{process_guid}" }

      context 'when there is an nsync url configured' do
        context 'when an endpoint is available' do
          before do
            stub_request(:put, desire_app_url).to_return(status: 202)
          end

          it 'calls nsync with the desire message' do
            expect(client.desire_app(process_guid, desire_message)).to be_nil
            expect(a_request(:put, desire_app_url).with(body: desire_message, headers: content_type_header)).to have_been_made.once
          end
        end

        context 'when the endpoint is unavailable' do
          it 'retries and eventually raises RunnerUnavailable' do
            stub = stub_request(:put, desire_app_url).to_raise(Errno::ECONNREFUSED)

            expect { client.desire_app(process_guid, desire_message) }.to raise_error(CloudController::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the endpoint fails' do
          before do
            stub_request(:put, desire_app_url).to_return(status: 500, body: '')
          end

          it 'raises RunnerError' do
            expect { client.desire_app(process_guid, desire_message) }.to raise_error(CloudController::Errors::ApiError, /desire app failed: 500/i)
          end
        end

        describe 'timing out' do
          let(:http) { double(:http) }
          let(:expected_timeout) { 10 }

          before do
            allow(Net::HTTP).to receive(:new).and_return(http)
            allow(http).to receive(:put).and_return(double(:http_response, body: '{}', code: '202'))
            allow(http).to receive(:read_timeout=)
            allow(http).to receive(:open_timeout=)
          end

          it 'sets the read_timeout' do
            client.desire_app(process_guid, desire_message)
            expect(http).to have_received(:read_timeout=).with(expected_timeout)
          end

          it 'sets the open_timeout' do
            client.desire_app(process_guid, desire_message)
            expect(http).to have_received(:open_timeout=).with(expected_timeout)
          end
        end
      end

      context 'when the nsync url is missing' do
        before do
          TestConfig.override(diego: { nsync_url: nil })
        end

        it 'raises RunnerUnavailable' do
          expect { client.desire_app(process_guid, desire_message) }.to raise_error(CloudController::Errors::ApiError, /invalid config/)
        end
      end
    end

    describe '#stop_app' do
      let(:stop_app_url) { "#{TestConfig.config[:diego][:nsync_url]}/v1/apps/#{process_guid}" }

      context 'when there is an nsync url configured' do
        context 'when the endpoint is available' do
          before do
            stub_request(:delete, stop_app_url).to_return(status: 202)
          end

          it 'calls the nsync with a delete request' do
            expect(client.stop_app(process_guid)).to be_nil
            expect(a_request(:delete, stop_app_url).with(body: nil, headers: content_type_header)).to have_been_made.once
          end

          context 'when nsync returns a 404' do
            before do
              stub_request(:delete, stop_app_url).to_return(status: 404)
            end

            it 'does not raise an error' do
              expect { client.stop_app(process_guid) }.to_not raise_error
            end
          end
        end

        context 'when the endpoint is unavailable' do
          it 'retries and eventually raises RunnerUnavailable' do
            stub = stub_request(:delete, stop_app_url).to_raise(Errno::ECONNREFUSED)

            expect { client.stop_app(process_guid) }.to raise_error(CloudController::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the endpoint fails' do
          before do
            stub_request(:delete, stop_app_url).to_return(status: 500, body: '')
          end

          it 'raises RunnerError' do
            expect { client.stop_app(process_guid) }.to raise_error(CloudController::Errors::ApiError, /stop app failed: 500/i)
          end
        end
      end
    end

    describe '#stop_index' do
      let(:index) { 1 }
      let(:stop_index_url) { "#{TestConfig.config[:diego][:nsync_url]}/v1/apps/#{process_guid}/index/#{index}" }

      context 'when there is an nsync url configured' do
        context 'when the endpoint is available' do
          before do
            stub_request(:delete, stop_index_url).to_return(status: 202)
          end

          it 'calls the nsync with a delete request' do
            expect(client.stop_index(process_guid, index)).to be_nil
            expect(a_request(:delete, stop_index_url).with(body: nil, headers: content_type_header)).to have_been_made.once
          end

          context 'when nsync returns a 404' do
            before do
              stub_request(:delete, stop_index_url).to_return(status: 404)
            end

            it 'does not raise an error' do
              expect { client.stop_index(process_guid, index) }.to_not raise_error
            end
          end
        end

        context 'when the endpoint is unavailable' do
          it 'retries and eventually raises RunnerUnavailable' do
            stub = stub_request(:delete, stop_index_url).to_raise(Errno::ECONNREFUSED)

            expect { client.stop_index(process_guid, index) }.to raise_error(CloudController::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
          end
        end

        context 'when the endpoint fails' do
          before do
            stub_request(:delete, stop_index_url).to_return(status: 500, body: '')
          end

          it 'raises RunnerError' do
            expect { client.stop_index(process_guid, index) }.to raise_error(CloudController::Errors::ApiError, /stop index failed: 500/i)
          end
        end
      end

      context 'when the nsync url is missing' do
        before do
          TestConfig.override(diego: { nsync_url: nil })
        end

        it 'raises RunnerUnavailable' do
          expect { client.stop_index(process_guid, index) }.to raise_error(CloudController::Errors::ApiError, /invalid config/)
        end
      end
    end

    describe '#desire_task' do
      let(:content_type_header) { { 'Content-Type' => 'application/json' } }
      let(:droplet) { VCAP::CloudController::DropletModel.make }
      let(:task) { VCAP::CloudController::TaskModel.make(droplet: droplet, state: 'PENDING') }
      let(:config) { VCAP::CloudController::Config.new({}) }
      let(:client_url) { "#{config.get(:diego, :nsync_url)}/v1/tasks" }

      context 'when the config is missing a diego task url' do
        it 'sets the state to FAILED and returns an error' do
          expect { client.desire_task(task) }.to raise_error CloudController::Errors::ApiError, /Diego Task URL does not exist/
          expect(task.state).to eq('FAILED')
          expect(task.failure_reason).to eq('Unable to request task to be run')
        end
      end

      context 'when there is a valid config' do
        let(:config) do
          VCAP::CloudController::Config.new({
            diego: { nsync_url: 'http://nsync.service.cf.internal:8787' },
            internal_api: {
              auth_user: 'my-cool-user',
              auth_password: 'my-not-so-cool-password'
            },
            internal_service_hostname: 'hostname'
          })
        end
        let(:protocol) { instance_double(VCAP::CloudController::Diego::TaskProtocol) }
        let(:desired_message) { MultiJson.dump({ process_guid: 'process-guid' }) }

        before do
          allow(VCAP::CloudController::Diego::TaskProtocol).to receive(:new).and_return(protocol)
          allow(protocol).to receive(:task_request).and_return(desired_message)
          stub_request(:post, client_url).to_return(status: 202, body: '')
        end

        it 'sets the task state as RUNNING' do
          expect { client.desire_task(task) }.not_to raise_error
          expect(task.state).to eq('RUNNING')
        end

        it 'send the request with a proper json body' do
          expect { client.desire_task(task) }.not_to raise_error
          expect(
            a_request(:post, client_url).with(body: desired_message, headers: content_type_header)
          ).to have_been_made.once
        end

        context 'when the task url is unavailable' do
          it 'retries and eventually raises TaskWorkerUnavailable' do
            stub = stub_request(:post, client_url).to_raise(Errno::ECONNREFUSED)

            expect { client.desire_task(task) }.to raise_error(CloudController::Errors::ApiError, /connection refused/i)
            expect(stub).to have_been_requested.times(3)
            expect(task.state).to eq('FAILED')
            expect(task.failure_reason).to eq('Unable to request task to be run')
          end
        end

        context 'when we do not receive a 202 from the task endpoint' do
          before do
            stub_request(:post, client_url).to_return(status: 500, body: '')
          end

          it 'raises a TaskError' do
            expect { client.desire_task(task) }.to raise_error(CloudController::Errors::ApiError, /task failed: 500/i)
            expect(task.state).to eq('FAILED')
            expect(task.failure_reason).to eq('Unable to request task to be run')
          end
        end
      end
    end

    describe '#cancel_task' do
      let(:content_type_header) { { 'Content-Type' => 'application/json' } }
      let(:task) { VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::CANCELING_STATE) }
      let(:config) { VCAP::CloudController::Config.new({}) }
      let(:client_url) { "#{config.get(:diego, :nsync_url)}/v1/tasks/#{task.guid}" }

      context 'when the config is missing a diego task url' do
        it 'leaves the state as CANCELING and returns an error' do
          expect { client.cancel_task(task) }.to raise_error CloudController::Errors::ApiError, /Diego Task URL does not exist/
          expect(task.state).to eq(VCAP::CloudController::TaskModel::CANCELING_STATE)
        end
      end

      context 'when there is a valid config' do
        let(:config) do
          VCAP::CloudController::Config.new({
            diego: { nsync_url: 'http://nsync.service.cf.internal:8787' },
            internal_api: {
              auth_user: 'my-cool-user',
              auth_password: 'my-not-so-cool-password'
            },
            internal_service_hostname: 'hostname'
          })
        end

        before do
          stub_request(:delete, client_url).to_return(status: 202, body: '')
        end

        it 'keeps the task state as CANCELING' do
          expect { client.cancel_task(task) }.not_to raise_error
          expect(task.state).to eq(VCAP::CloudController::TaskModel::CANCELING_STATE)
        end

        it 'sends the proper DELETE request to nsync' do
          expect { client.cancel_task(task) }.not_to raise_error
          expect(
            a_request(:delete, client_url).with(body: '', headers: content_type_header)
          ).to have_been_made.once
        end

        context 'when the task url is unavailable' do
          it 'retries and eventually raises TaskWorkerUnavailable' do
            stub = stub_request(:delete, client_url).to_raise(Errno::ECONNREFUSED)

            expect { client.cancel_task(task) }.not_to raise_error
            expect(stub).to have_been_requested.times(3)
            expect(task.state).to eq('CANCELING')
          end
        end

        context 'when we do not receive a 202 from the task endpoint' do
          before do
            stub_request(:delete, client_url).to_return(status: 500, body: '')
          end

          it 'does not raise an error' do
            expect { client.cancel_task(task) }.not_to raise_error
            expect(task.state).to eq('CANCELING')
          end
        end
      end
    end
  end
end
