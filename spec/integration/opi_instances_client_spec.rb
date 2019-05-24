require 'spec_helper'

$LOAD_PATH.unshift('app')

require 'cloud_controller/opi/instances_client'

# This spec requires the OPI binary to be in $PATH
skip_opi_tests = ENV['CF_RUN_OPI_SPECS'] != 'true'
RSpec.describe(OPI::InstancesClient, opi: skip_opi_tests) do
  let(:opi_url) { 'http://localhost:8085' }
  let(:config) do
    TestConfig.override(
      opi: {
        url: opi_url
      },
    )
  end
  subject(:client) { described_class.new(config) }
  let(:process) { double(guid: 'jeff', version: '0.1.0') }

  before :all do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def up?(url)
    HTTPClient.new.get(url)
  rescue Errno::ECONNREFUSED
    yield if block_given?
    nil
  end

  before do
    @pid = Process.spawn('opi simulator')

    raise 'Boom' unless 5.times.any? do
      up?(opi_url) {
        sleep 0.1
      }
    end
  end

  after do
    Process.kill('SIGTERM', @pid)
  end

  context 'OPI system tests' do
    context 'Get instances' do
      let(:expected_instances) {
        [OPI::InstancesClient::ActualLRP.new({ 'index' => 0, 'state' => 'RUNNING', 'since' => 123456 }, 'jeff-0.1.0'),
         OPI::InstancesClient::ActualLRP.new({ 'index' => 1, 'state' => 'RUNNING', 'since' => 567891 }, 'jeff-0.1.0')]
      }

      it 'does not error' do
        expect { client.lrp_instances(process) }.to_not raise_error
      end

      it 'fetches instances' do
        instances = client.lrp_instances(process)
        expect(instances).to eq(expected_instances)
      end

      context 'when process guid does not exist' do
        let(:process) { double(guid: 'jeff-goldblum', version: '0.2.0') }

        it 'raises an error' do
          expect { client.lrp_instances(process) }.to raise_error(CloudController::Errors::NoRunningInstances, 'No running instances')
        end
      end
    end
  end
end
