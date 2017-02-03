require 'spec_helper'
require 'cloud_controller/diego/bbs_stager_client'

module VCAP::CloudController::Diego
  RSpec.describe BbsStagerClient do
    let(:staging_guid) { 'staging-guid' }
    let(:bbs_client) { instance_double(::Diego::Client) }

    subject(:client) { BbsStagerClient.new(bbs_client) }

    describe '#stage' do
      let(:staging_message) { instance_double(::Diego::Bbs::Models::TaskDefinition) }

      before do
        allow(bbs_client).to receive(:desire_task).and_return(::Diego::Bbs::Models::TaskLifecycleResponse.new)
      end

      it 'desires a task' do
        client.stage(staging_guid, staging_message)

        expect(bbs_client).to have_received(:desire_task).with(task_definition: staging_message, task_guid: staging_guid, domain: 'cf-app-staging')
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:desire_task).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.stage(staging_guid, staging_message)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('StagerUnavailable')
          end
        end
      end

      context 'when bbs returns a response with an error' do
        before do
          allow(bbs_client).to receive(:desire_task).and_return(
            ::Diego::Bbs::Models::TaskLifecycleResponse.new(
              error: ::Diego::Bbs::Models::Error.new(
                type:    ::Diego::Bbs::Models::Error::Type::InvalidRecord,
                message: 'error message'
              )))
        end

        it 'raises an api error' do
          expect {
            client.stage(staging_guid, staging_message)
          }.to raise_error(CloudController::Errors::ApiError, /staging failed: error message/) do |e|
            expect(e.name).to eq('StagerError')
          end
        end
      end
    end

    describe '#stop_staging' do
      before do
        allow(bbs_client).to receive(:cancel_task).and_return(::Diego::Bbs::Models::TaskLifecycleResponse.new)
      end

      it 'cancels a task' do
        client.stop_staging(staging_guid)

        expect(bbs_client).to have_received(:cancel_task).with('staging-guid')
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:cancel_task).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.stop_staging(staging_guid)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('StagerUnavailable')
          end
        end
      end

      context 'when bbs returns a response with an error' do
        let(:error_type) { ::Diego::Bbs::Models::Error::Type::InvalidRecord }
        before do
          allow(bbs_client).to receive(:cancel_task).and_return(
            ::Diego::Bbs::Models::TaskLifecycleResponse.new(
              error: ::Diego::Bbs::Models::Error.new(
                type: error_type,
                message: 'error message'
              )))
        end

        it 'raises an api error' do
          expect {
            client.stop_staging(staging_guid)
          }.to raise_error(CloudController::Errors::ApiError, /stop staging failed: error message/) do |e|
            expect(e.name).to eq('StagerError')
          end
        end

        context 'if the error is a "ResourceNotFound"' do
          let(:error_type) { ::Diego::Bbs::Models::Error::Type::ResourceNotFound }

          it 'does not raise an error' do
            expect {
              client.stop_staging(staging_guid)
            }.not_to raise_error
          end
        end
      end
    end
  end
end
