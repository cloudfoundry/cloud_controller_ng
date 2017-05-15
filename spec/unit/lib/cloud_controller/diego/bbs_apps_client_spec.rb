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

      context 'when the bbs response contains an invalid request error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::InvalidRequest, message: 'bad request') }

        it 'raises an RunnerInvalidRequest api error' do
          expect {
            client.desire_app(lurp)
          }.to raise_error(CloudController::Errors::ApiError, /bad request/) do |e|
            expect(e.name).to eq('RunnerInvalidRequest')
          end
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

    describe '#stop_app' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPLifecycleResponse.new(error: error) }
      let(:process_guid) { 'process-guid' }
      let(:error) { nil }

      before do
        allow(bbs_client).to receive(:remove_desired_lrp).with('process-guid').and_return(bbs_response)
      end

      it 'does not raise error' do
        expect { client.stop_app(process_guid) }.to_not raise_error
        expect(bbs_client).to have_received(:remove_desired_lrp).with(process_guid)
      end

      context 'when the bbs response contains a resource not found error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound) }

        it 'returns nil' do
          expect(client.stop_app(process_guid)).to be_nil
        end
      end

      context 'when the bbs response contains any other error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.stop_app(process_guid)
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('RunnerError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:remove_desired_lrp).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.stop_app(process_guid)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end
    end

    describe '#stop_index' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::ActualLRPLifecycleResponse.new(error: error) }
      let(:process_guid) { 'process-guid' }
      let(:index) { 9 }
      let(:actual_lrp_key) { ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: process_guid, index: index, domain: APP_LRP_DOMAIN) }
      let(:error) { nil }

      before do
        allow(bbs_client).to receive(:retire_actual_lrp).with(actual_lrp_key).and_return(bbs_response)
      end

      it 'does not raise error' do
        expect { client.stop_index(process_guid, index) }.to_not raise_error
        expect(bbs_client).to have_received(:retire_actual_lrp).with(actual_lrp_key)
      end

      context 'when the bbs response contains a resource not found error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound) }

        it 'returns nil' do
          expect(client.stop_index(process_guid, index)).to be_nil
        end
      end

      context 'when the bbs response contains any other error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.stop_index(process_guid, index)
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('RunnerError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:retire_actual_lrp).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.stop_index(process_guid, index)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
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

      context 'when the bbs response contains an invalid request error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::InvalidRequest, message: 'bad request') }

        it 'raises an RunnerInvalidRequest api error' do
          expect {
            client.update_app(process_guid, lrp_update)
          }.to raise_error(CloudController::Errors::ApiError, /bad request/) do |e|
            expect(e.name).to eq('RunnerInvalidRequest')
          end
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

    describe '#fetch_scheduling_infos' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPSchedulingInfosResponse.new(desired_lrp_scheduling_infos: lrp_scheduling_infos, error: error) }
      let(:lrp_scheduling_infos) { [::Diego::Bbs::Models::DesiredLRPSchedulingInfo.new] }
      let(:error) { nil }

      before do
        allow(bbs_client).to receive(:desired_lrp_scheduling_infos).with(APP_LRP_DOMAIN).and_return(bbs_response)
      end

      it 'returns lrp scheduling infos' do
        returned_infos = client.fetch_scheduling_infos
        expect(returned_infos).to eq(lrp_scheduling_infos)
      end

      context 'when the bbs response contains any error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.fetch_scheduling_infos
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('RunnerError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:desired_lrp_scheduling_infos).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.fetch_scheduling_infos
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end
    end

    describe '#bump_freshness' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::UpsertDomainResponse.new(error: error) }
      let(:error) { nil }

      before do
        allow(bbs_client).to receive(:upsert_domain).with(domain: APP_LRP_DOMAIN, ttl: APP_LRP_DOMAIN_TTL).and_return(bbs_response)
      end

      it 'sends the upsert domain to diego' do
        client.bump_freshness
        expect(bbs_client).to have_received(:upsert_domain).with(domain: APP_LRP_DOMAIN, ttl: APP_LRP_DOMAIN_TTL)
      end

      context 'when the bbs response contains any other error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.bump_freshness
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('RunnerError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:upsert_domain).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.bump_freshness
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end
    end
  end
end
