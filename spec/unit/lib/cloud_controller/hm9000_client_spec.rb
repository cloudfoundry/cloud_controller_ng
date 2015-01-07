require 'spec_helper'

def generate_hm_api_response(app, running_instances, crash_counts=[])
  result = {
    droplet: app.guid,
    version: app.version,
    desired: {
      id: app.guid,
      version: app.version,
      instances: app.instances,
      state: app.state,
      package_state: app.package_state,
    },
    instance_heartbeats: [],
    crash_counts: []
  }

  running_instances.each do |running_instance|
    result[:instance_heartbeats].push({
                                        droplet: app.guid,
                                        version: app.version,
                                        instance: running_instance[:instance_guid] || Sham.guid,
                                        index: running_instance[:index],
                                        state: running_instance[:state],
                                        state_timestamp: 3.141
                                      })
  end

  crash_counts.each do |crash_count|
    result[:crash_counts].push({
                                  droplet: app.guid,
                                  version: app.version,
                                  instance_index: crash_count[:instance_index],
                                  crash_count: crash_count[:crash_count],
                                  created_at: 1234567
                               })
  end

  JSON.parse(result.to_json)
end

module VCAP::CloudController
  describe VCAP::CloudController::Dea::HM9000::Client do
    let(:app0instances) { 1 }
    let(:app0) { AppFactory.make(instances: app0instances) }
    let(:app1) { AppFactory.make(instances: 1) }
    let(:app2) { AppFactory.make(instances: 1) }
    let(:app0_request_should_fail) { false }

    let(:hm9000_config) do
      {
        flapping_crash_count_threshold: 3,
        hm9000: {
          url: 'https://some-hm9000-api:9492'
        },
        internal_api: {
          auth_user: 'myuser',
          auth_password: 'mypass'
        }
      }
    end

    let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: 'RUNNING' }]) }
    let(:app_1_api_response) { generate_hm_api_response(app1, [{ index: 0, state: 'CRASHED' }]) }
    let(:app_2_api_response) { generate_hm_api_response(app2, [{ index: 0, state: 'RUNNING' }]) }

    let(:hm9000_url) { 'https://myuser:mypass@some-hm9000-api:9492' }
    let(:legacy_client) { double(:legacy_client) }

    subject(:hm9000_client) { VCAP::CloudController::Dea::HM9000::Client.new(legacy_client, hm9000_config) }

    describe 'healthy_instances' do
      context 'with a single desired and running instance' do
        it 'should return the correct number of healthy instances' do
          expected_request = [{ droplet: app0.guid, version: app0.version }].to_json
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

          result = subject.healthy_instances(app0)

          expect(a_request(:post, "#{hm9000_url}/bulk_app_state").with(body: expected_request)).to have_been_made
          expect(result).to eq(1)
        end
      end

      context 'when the api response is garbage' do
        it 'should return -1' do
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 200, body: [].to_json).then.
            to_return(status: 200, body: {}.to_json).then.
            to_return(status: 200, body: { foo: { jim: 'bar' } }.to_json)

          3.times { expect(hm9000_client.healthy_instances(app0)).to eq(-1) }
        end
      end

      context 'with multiple desired instances' do
        let(:app0instances) { 3 }

        context 'when all the desired instances are running' do
          let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: 'RUNNING' }, { index: 1, state: 'RUNNING' }, { index: 2, state: 'STARTING' }]) }

          it 'should return the number of running instances' do
            stub_request(:post, "#{hm9000_url}/bulk_app_state").
              to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

            expect(hm9000_client.healthy_instances(app0)).to eq(3)
          end
        end

        context 'when only some of the desired instances are running' do
          let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: 'RUNNING' }, { index: 2, state: 'STARTING' }]) }

          it 'should return the number of running instances in the desired range' do
            stub_request(:post, "#{hm9000_url}/bulk_app_state").
              to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

            expect(hm9000_client.healthy_instances(app0)).to eq(2)
          end
        end

        context 'when there are extra instances outside of the desired range' do
          let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: 'RUNNING' }, { index: 2, state: 'STARTING' }, { index: 3, state: 'RUNNING' }]) }

          it 'should only return the number of running instances in the desired range' do
            stub_request(:post, "#{hm9000_url}/bulk_app_state").
              to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

            expect(hm9000_client.healthy_instances(app0)).to eq(2)
          end
        end

        context 'when there are multiple instances running on the same index' do
          let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: 'RUNNING' }, { index: 2, state: 'STARTING' }, { index: 2, state: 'RUNNING' }]) }

          it 'should only count one of the instances' do
            stub_request(:post, "#{hm9000_url}/bulk_app_state").
              to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

            expect(hm9000_client.healthy_instances(app0)).to eq(2)
          end
        end

        context 'when some of the desired instances are crashed' do
          let(:app_0_api_response) do
            generate_hm_api_response(app0, [{ index: 0, state: 'RUNNING' }, { index: 1, state: 'CRASHED' }, { index: 2, state: 'STARTING' }, { index: 2, state: 'CRASHED' }])
          end

          it 'should not count the crashed instances' do
            stub_request(:post, "#{hm9000_url}/bulk_app_state").
              to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

            expect(hm9000_client.healthy_instances(app0)).to eq(2)
          end
        end
      end

      context 'when, mysteriously, a response is received that is not empty but is missing instance heartbeats' do
        let(:app_0_api_response) { { droplet: app0.guid, version: app0.version } }

        it 'should return 0' do
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

          expect(hm9000_client.healthy_instances(app0)).to eq(-1)
        end
      end
    end

    describe 'healthy_instances_bulk' do
      context 'when the provided app list is empty' do
        it 'returns an empty hash' do
          expect(subject.healthy_instances_bulk([])).to eq({})
        end
      end

      context 'when the provided app list is nil' do
        it 'returns and empty hash' do
          expect(subject.healthy_instances_bulk(nil)).to eq({})
        end
      end

      context 'when called with multiple apps' do
        it 'returns a hash of app guid => running instance count' do
          expected_request = [{ droplet: app0.guid, version: app0.version }, { droplet: app1.guid, version: app1.version }, { droplet: app2.guid, version: app2.version }].to_json
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 200, body: {
            app0.guid => app_0_api_response,
            app1.guid => app_1_api_response,
            app2.guid => app_2_api_response
          }.to_json)

          result = subject.healthy_instances_bulk([app0, app1, app2])

          expect(a_request(:post, "#{hm9000_url}/bulk_app_state").with(body: expected_request)).to have_been_made
          expect(result).to eq({
            app0.guid => 1, app1.guid => 0, app2.guid => 1
          })
        end
      end
    end

    describe 'find_crashes' do
      let(:app_0_api_response) do
        generate_hm_api_response(app0, [
          { index: 0, state: 'CRASHED', instance_guid: 'sham' },
          { index: 1, state: 'CRASHED', instance_guid: 'wow' },
          { index: 1, state: 'RUNNING' }
        ])
      end

      context 'when the request fails' do
        it 'should return an empty array' do
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 500)

          expect(hm9000_client.find_crashes(app0)).to eq([])
        end
      end

      context 'when the request succeeds' do
        it 'should return an array of all the crashed instances' do
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

          crashes = hm9000_client.find_crashes(app0)
          expect(crashes).to have(2).items
          expect(crashes).to include({ 'instance' => 'sham', 'since' => 3.141 })
          expect(crashes).to include({ 'instance' => 'wow', 'since' => 3.141 })
        end
      end
    end

    describe 'find_flapping_indices' do
      let(:app_0_api_response) do
        generate_hm_api_response(app0, [], [{ instance_index: 0, crash_count: 3 }, { instance_index: 1, crash_count: 1 }, { instance_index: 2, crash_count: 10 }])
      end

      context 'when the request fails' do
        it 'should return an empty array' do
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 500)

          expect(hm9000_client.find_flapping_indices(app0)).to eq([])
        end
      end

      context 'when the request succeeds' do
        it 'should return an array of all the crashed instances' do
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 200, body: { app0.guid => app_0_api_response }.to_json)

          flapping_indices = hm9000_client.find_flapping_indices(app0)
          expect(flapping_indices).to have(2).items
          expect(flapping_indices).to include({ 'index' => 0, 'since' => 1234567 })
          expect(flapping_indices).to include({ 'index' => 2, 'since' => 1234567 })
        end
      end
    end

    context 'when the hm9000 http api is not present' do
      before { stub_request(:post, "#{hm9000_url}/bulk_app_state").to_return(status: 404) }
      let(:legacy_return_value) { double(:legacy_return_value) }

      describe 'healthy_instances' do
        it 'calls through the legacy nats client' do
          allow(legacy_client).to receive(:healthy_instances).with(app0).and_return(legacy_return_value)
          actual_return_value = hm9000_client.healthy_instances(app0)
          expect(actual_return_value).to eq(legacy_return_value)
        end
      end

      describe 'healthy_instances_bulk' do
        it 'calls through the legacy nats client' do
          allow(legacy_client).to receive(:healthy_instances_bulk).with([app0]).and_return(legacy_return_value)
          actual_return_value = hm9000_client.healthy_instances_bulk([app0])
          expect(actual_return_value).to eq(legacy_return_value)
        end
      end

      describe 'find_crashes' do
        it 'calls through the legacy nats client' do
          allow(legacy_client).to receive(:find_crashes).with(app0).and_return(legacy_return_value)
          actual_return_value = hm9000_client.find_crashes(app0)
          expect(actual_return_value).to eq(legacy_return_value)
        end
      end

      describe 'find_flapping_indices' do
        it 'calls through the legacy nats client' do
          allow(legacy_client).to receive(:find_flapping_indices).with(app0).and_return(legacy_return_value)
          actual_return_value = hm9000_client.find_flapping_indices(app0)
          expect(actual_return_value).to eq(legacy_return_value)
        end
      end
    end

    describe 'ssl certificate validation' do
      context 'when skip_cert_verify is true' do
        let(:hm9000_config) do
          {
            skip_cert_verify: true,
            flapping_crash_count_threshold: 3,
            hm9000: {
              url: 'https://some-hm9000-api:9492'
            },
            internal_api: {
              auth_user: 'myuser',
              auth_password: 'mypass'
            }
          }
        end

        it 'does not verify the cert' do
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 200, body: {}.to_json)

          expect_any_instance_of(HTTPClient::SSLConfig).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

          subject.healthy_instances(app0)
        end
      end

      context 'when skip_cert_verify is false' do
        let(:hm9000_config) do
          {
            skip_cert_verify: false,
            flapping_crash_count_threshold: 3,
            hm9000: {
              url: 'https://some-hm9000-api:9492'
            },
            internal_api: {
              auth_user: 'myuser',
              auth_password: 'mypass'
            }
          }
        end

        it 'does not verify the cert' do
          stub_request(:post, "#{hm9000_url}/bulk_app_state").
            to_return(status: 200, body: {}.to_json)

          expect_any_instance_of(HTTPClient::SSLConfig).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

          subject.healthy_instances(app0)
        end
      end
    end
  end
end
