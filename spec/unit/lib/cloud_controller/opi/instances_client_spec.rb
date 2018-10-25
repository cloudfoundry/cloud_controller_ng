require 'spec_helper'
require 'cloud_controller/opi/instances_client'

RSpec.describe(OPI::InstancesClient) do
  subject(:client) { described_class.new(opi_url) }
  let(:opi_url) { 'http://opi.service.cf.internal:8077' }
  let(:process) { double(guid: 'my-process-guid') }

  context '#lrp_instances' do
    context 'when request executes successfully' do
      subject(:actual_lrps) { client.lrp_instances(process) }

      let(:response_body) do
        {
          process_guid: 'my-guid-0',
          instances: [
            { index: 42, state: 'RUNNING' }
          ]
        }.to_json
      end

      before do
        stub_request(:get, "#{opi_url}/apps/#{process.guid}/instances").
          to_return(status: 200, body: response_body)
      end

      it 'executes expected http request' do
        client.lrp_instances(process)
        expect(WebMock).to have_requested(:get, "#{opi_url}/apps/#{process.guid}/instances")
      end

      it 'returns the expected amount of actual lrps' do
        expect(actual_lrps).to respond_to(:size)
        expect(actual_lrps.size).to eq(1)
      end

      it 'provides the index' do
        actual_lrp = actual_lrps.first
        expect(actual_lrp).to respond_to(:actual_lrp_key)
        expect(actual_lrp.actual_lrp_key).to respond_to(:index)
        expect(actual_lrp.actual_lrp_key.index).to eq(42)
      end

      it 'provides the state' do
        actual_lrp = actual_lrps.first
        expect(actual_lrp).to respond_to(:state)
        expect(actual_lrp.state).to eq('RUNNING')
      end

      it 'provides the process guid' do
        actual_lrp = actual_lrps.first
        expect(actual_lrp.actual_lrp_key).to respond_to(:process_guid)
        expect(actual_lrp.actual_lrp_key.process_guid).to eq('my-guid-0')
      end

      it 'provides a since value' do
        actual_lrp = actual_lrps.first
        expect(actual_lrp).to respond_to(:since)
        expect(actual_lrp.since).to eq(0)
      end

      it 'provides a placement_error value' do
        actual_lrp = actual_lrps.first
        expect(actual_lrp).to respond_to(:placement_error)
        expect(actual_lrp.placement_error).to eq('')
      end

      context 'when having multiple actual LRPs' do
        let(:response_body) do
          {
            process_guid: 'my-guid-0',
            instances: [
              { index: 11, state: 'RUNNING' },
              { index: 23, state: 'CLAIMED' },
              { index: 42, state: 'CLAIMED' }
            ]
          }.to_json
        end

        it 'returns the expected amount of actual lrps' do
          expect(actual_lrps.size).to eq(3)
        end

        it 'provides the indexes' do
          expect(actual_lrps[0].actual_lrp_key.index).to eq(11)
          expect(actual_lrps[1].actual_lrp_key.index).to eq(23)
          expect(actual_lrps[2].actual_lrp_key.index).to eq(42)
        end

        it 'provides the states' do
          expect(actual_lrps[0].state).to eq('RUNNING')
          expect(actual_lrps[1].state).to eq('CLAIMED')
          expect(actual_lrps[2].state).to eq('CLAIMED')
        end

        it 'provides the single guid of the process' do
          expect(actual_lrps[0].actual_lrp_key.process_guid).to eq('my-guid-0')
          expect(actual_lrps[1].actual_lrp_key.process_guid).to eq('my-guid-0')
          expect(actual_lrps[2].actual_lrp_key.process_guid).to eq('my-guid-0')
        end
      end

      context 'when there are no running instances' do
        let(:response_body) do
          { error: 'no-running-instances' }.to_json
        end

        it 'raises NoRunningInstances error' do
          expect { client.lrp_instances(process) }.to raise_error(CloudController::Errors::NoRunningInstances)
          expect(a_request(:get, "#{opi_url}/apps/#{process.guid}/instances")).to have_been_made.times(5)
        end
      end

      context 'when the instances are not initially availalbe' do
        let(:error_response_body) do
          { error: 'no-running-instances' }.to_json
        end

        before do
          stub_request(:get, "#{opi_url}/apps/#{process.guid}/instances").
            to_return(status: 200, body: error_response_body).
            then.to_return(status: 200, body: error_response_body).
            then.to_return(status: 200, body: error_response_body).
            then.to_return(status: 200, body: response_body)
        end

        it 'should succeed after several retries' do
          client.lrp_instances(process)
          expect(a_request(:get, "#{opi_url}/apps/#{process.guid}/instances")).to have_been_made.times(4)
        end
      end
    end

    context '#desired_lrp_instance' do
      it 'should return a DesiredLRP with a placeholder PlacmentTags' do
        desired_lrp = client.desired_lrp_instance(process)
        expect(desired_lrp.PlacementTags.first).to eq('placeholder')
      end
    end
  end
end
