require 'spec_helper'

module VCAP::CloudController::Diego
  RSpec.describe BbsAppsClient do
    subject(:client) { BbsAppsClient.new(bbs_client) }

    describe '#desire_app' do
      let(:bbs_client) { instance_double(::Diego::Client, desire_lrp: lurp_response) }

      let(:lurp) { ::Diego::Bbs::Models::DesiredLRP.new }
      let(:lurp_response) { ::Diego::Bbs::Models::DesiredLRPLifecycleResponse.new(error: error) }
      let(:error) { nil }

      it 'sends the lrp to diego' do
        client.desire_app(lurp)
        expect(bbs_client).to have_received(:desire_lrp).with(lurp)
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:desire_lrp).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.desire_app(lurp)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end

      context 'when the bbs response contains a conflict error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceConflict) }

        it 'returns false' do
          expect { client.desire_app(lurp) }.not_to raise_error
        end
      end

      context 'when bbs returns a response with any other error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(message: 'error message') }

        it 'raises an api error' do
          expect {
            client.desire_app(lurp)
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('RunnerError')
          end
        end
      end
    end

    describe '#get_app' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPResponse.new(desired_lrp: desired_lrp, error: error) }
      let(:process_guid) { 'process-guid' }
      let(:desired_lrp) { ::Diego::Bbs::Models::DesiredLRP.new(process_guid: process_guid) }
      let(:error) { nil }

      before do
        allow(bbs_client).to receive(:desired_lrp_by_process_guid).with('process-guid').and_return(bbs_response)
      end

      it 'returns the lrp if it exists' do
        returned_lrp = client.get_app(process_guid)
        expect(returned_lrp).to eq(desired_lrp)
      end

      context 'when the bbs response contains a resource not found error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound) }

        it 'returns nil' do
          expect(client.get_app(process_guid)).to be_nil
        end
      end

      context 'when the bbs response contains any other error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.get_app(process_guid)
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('RunnerError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:desired_lrp_by_process_guid).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.get_app(process_guid)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end
    end

    describe '#update_app' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPLifecycleResponse.new(error: error) }
      let(:error) { nil }

      let(:process_guid) { 'process-guid' }
      let(:lrp_update) { ::Diego::Bbs::Models::DesiredLRPUpdate.new(instances: 3) }

      before do
        allow(bbs_client).to receive(:update_desired_lrp).with(process_guid, lrp_update).and_return(bbs_response)
      end

      it 'sends the update lrp to diego' do
        client.update_app(process_guid, lrp_update)
        expect(bbs_client).to have_received(:update_desired_lrp).with(process_guid, lrp_update)
      end

      context 'when the bbs response contains a conflict error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceConflict) }

        it 'returns false' do
          expect { client.update_app(process_guid, lrp_update) }.not_to raise_error
        end
      end

      context 'when the bbs response contains any other error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.update_app(process_guid, lrp_update)
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('RunnerError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:update_desired_lrp).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.update_app(process_guid, lrp_update)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end
    end
  end
end
