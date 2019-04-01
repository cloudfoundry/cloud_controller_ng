require 'spec_helper'

module VCAP::CloudController::Diego
  RSpec.describe BbsAppsClient do
    subject(:client) { BbsAppsClient.new(bbs_client, config) }
    let(:config) { VCAP::CloudController::Config.new({ default_health_check_timeout: 99 }) }

    describe '#desire_app' do
      let(:bbs_client) { instance_double(::Diego::Client, desire_lrp: lrp_response) }
      let(:lrp) { ::Diego::Bbs::Models::DesiredLRP.new }
      let(:process) { VCAP::CloudController::ProcessModel.make }
      let(:lrp_response) { ::Diego::Bbs::Models::DesiredLRPLifecycleResponse.new(error: lifecycle_error) }
      let(:lifecycle_error) { nil }

      let(:app_recipe_builder) { instance_double(AppRecipeBuilder, build_app_lrp: build_lrp) }
      let(:build_lrp) { instance_double(::Diego::Bbs::Models::DesiredLRP) }

      before do
        allow(AppRecipeBuilder).to receive(:new).with(config: config, process: process).and_return(app_recipe_builder)
      end

      context 'app_recipe_builder succeeds' do
        before do
          allow(app_recipe_builder).to receive(:build_app_lrp).and_return(lrp)
        end
        it 'sends the lrp to diego' do
          client.desire_app(process)
          expect(bbs_client).to have_received(:desire_lrp).with(lrp)
        end

        context 'when bbs client errors' do
          before do
            allow(bbs_client).to receive(:desire_lrp).and_raise(::Diego::Error.new('boom'))
          end

          it 'raises an api error' do
            expect {
              client.desire_app(process)
            }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
              expect(e.name).to eq('RunnerUnavailable')
            end
          end
        end

        context 'when the bbs response contains a conflict error' do
          let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceConflict) }

          it 'does not raise error' do
            expect { client.desire_app(process) }.not_to raise_error
          end
        end

        context 'when the bbs response contains an invalid request error' do
          let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::InvalidRequest, message: 'bad request') }

          it 'raises an RunnerInvalidRequest api error' do
            expect {
              client.desire_app(process)
            }.to raise_error(CloudController::Errors::ApiError, /bad request/) do |e|
              expect(e.name).to eq('RunnerInvalidRequest')
            end
          end
        end

        context 'when bbs returns a response with any other error' do
          let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(message: 'error message') }

          it 'raises an api error' do
            expect {
              client.desire_app(process)
            }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
              expect(e.name).to eq('RunnerError')
            end
          end
        end
      end
      context 'app_recipe_builder fails' do
        let(:api_error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'bad error!') }

        before do
          allow(app_recipe_builder).to receive(:build_app_lrp).and_raise(api_error)
        end

        it 'passes the error' do
          expect { client.desire_app(process) }.to raise_error(CloudController::Errors::ApiError)
        end
      end

      context 'the client fails for its own reasons' do
        let(:error) { VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder::InvalidStack.new('lolololol') }

        before do
          allow(app_recipe_builder).to receive(:build_app_lrp).and_raise(error)
        end

        it 'annotates the error with process guid' do
          expect { client.desire_app(process) }.to raise_error("Process Guid: #{process.guid}: lolololol")
        end
      end
    end
    describe '#stop_app' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPLifecycleResponse.new(error: lifecycle_error) }
      let(:process_guid) { 'process-guid' }
      let(:lifecycle_error) { nil }

      before do
        allow(bbs_client).to receive(:remove_desired_lrp).with('process-guid').and_return(bbs_response)
      end

      it 'does not raise error' do
        expect { client.stop_app(process_guid) }.to_not raise_error
        expect(bbs_client).to have_received(:remove_desired_lrp).with(process_guid)
      end

      context 'when the bbs response contains a resource not found error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound) }

        it 'returns nil' do
          expect(client.stop_app(process_guid)).to be_nil
        end
      end

      context 'when the bbs response contains any other error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

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
      let(:bbs_response) { ::Diego::Bbs::Models::ActualLRPLifecycleResponse.new(error: lifecycle_error) }
      let(:process_guid) { 'process-guid' }
      let(:index) { 9 }
      let(:actual_lrp_key) { ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: process_guid, index: index, domain: APP_LRP_DOMAIN) }
      let(:lifecycle_error) { nil }

      before do
        allow(bbs_client).to receive(:retire_actual_lrp).with(actual_lrp_key).and_return(bbs_response)
      end

      it 'does not raise error' do
        expect { client.stop_index(process_guid, index) }.to_not raise_error
        expect(bbs_client).to have_received(:retire_actual_lrp).with(actual_lrp_key)
      end

      context 'when the bbs response contains a resource not found error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound) }

        it 'returns nil' do
          expect(client.stop_index(process_guid, index)).to be_nil
        end
      end

      context 'when the bbs response contains any other error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

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
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPResponse.new(desired_lrp: desired_lrp, error: lifecycle_error) }
      let(:process) { double(guid: 'process', version: 'guid') }
      let(:desired_lrp) { ::Diego::Bbs::Models::DesiredLRP.new(process_guid: 'process-guid') }
      let(:lifecycle_error) { nil }

      before do
        allow(bbs_client).to receive(:desired_lrp_by_process_guid).with('process-guid').and_return(bbs_response)
      end

      it 'returns the lrp if it exists' do
        returned_lrp = client.get_app(process)
        expect(returned_lrp).to eq(desired_lrp)
      end

      context 'when the bbs response contains a resource not found error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound) }

        it 'returns nil' do
          expect(client.get_app(process)).to be_nil
        end
      end

      context 'when the bbs response contains any other error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.get_app(process)
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
            client.get_app(process)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end
    end

    describe '#update_app' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPLifecycleResponse.new(error: lifecycle_error) }
      let(:lifecycle_error) { nil }

      let(:process) { double(guid: 'process', version: 'guid') }
      let(:process_guid) { 'process-guid' }
      let(:lrp_update) { ::Diego::Bbs::Models::DesiredLRPUpdate.new(instances: 3) }
      let(:recipe_builder) { instance_double(AppRecipeBuilder) }
      let(:existing_lrp) { double }

      before do
        allow(bbs_client).to receive(:update_desired_lrp).with(process_guid, lrp_update).and_return(bbs_response)
        allow(AppRecipeBuilder).to receive(:new).and_return(recipe_builder)
        allow(recipe_builder).to receive(:build_app_lrp_update).and_return(lrp_update)
      end

      it 'uses AppRecipeBuilder to build the updated lrp' do
        client.update_app(process, existing_lrp)
        expect(recipe_builder).to have_received(:build_app_lrp_update).
          with(existing_lrp)
      end

      it 'sends the update lrp to diego' do
        client.update_app(process, existing_lrp)
        expect(bbs_client).to have_received(:update_desired_lrp).with(process_guid, lrp_update)
      end

      context 'when the bbs response contains a conflict error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::ResourceConflict) }

        it 'returns false' do
          expect { client.update_app(process, existing_lrp) }.not_to raise_error
        end
      end

      context 'when the bbs response contains an invalid request error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::InvalidRequest, message: 'bad request') }

        it 'raises an RunnerInvalidRequest api error' do
          expect {
            client.update_app(process, existing_lrp)
          }.to raise_error(CloudController::Errors::ApiError, /bad request/) do |e|
            expect(e.name).to eq('RunnerInvalidRequest')
          end
        end
      end

      context 'when the bbs response contains any other error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.update_app(process, existing_lrp)
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
            client.update_app(process, existing_lrp)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('RunnerUnavailable')
          end
        end
      end
    end

    describe '#fetch_scheduling_infos' do
      let(:bbs_client) { instance_double(::Diego::Client) }
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPSchedulingInfosResponse.new(desired_lrp_scheduling_infos: lrp_scheduling_infos, error: lifecycle_error) }
      let(:lrp_scheduling_infos) { [::Diego::Bbs::Models::DesiredLRPSchedulingInfo.new] }
      let(:lifecycle_error) { nil }

      before do
        allow(bbs_client).to receive(:desired_lrp_scheduling_infos).with(APP_LRP_DOMAIN).and_return(bbs_response)
      end

      it 'returns lrp scheduling infos' do
        returned_infos = client.fetch_scheduling_infos
        expect(returned_infos).to eq(lrp_scheduling_infos)
      end

      context 'when the bbs response contains any error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

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
      let(:bbs_response) { ::Diego::Bbs::Models::UpsertDomainResponse.new(error: lifecycle_error) }
      let(:lifecycle_error) { nil }

      before do
        allow(bbs_client).to receive(:upsert_domain).with(domain: APP_LRP_DOMAIN, ttl: APP_LRP_DOMAIN_TTL).and_return(bbs_response)
      end

      it 'sends the upsert domain to diego' do
        client.bump_freshness
        expect(bbs_client).to have_received(:upsert_domain).with(domain: APP_LRP_DOMAIN, ttl: APP_LRP_DOMAIN_TTL)
      end

      context 'when the bbs response contains any other error' do
        let(:lifecycle_error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

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
