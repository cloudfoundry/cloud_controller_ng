require 'spec_helper'
require 'cloud_controller/diego/bbs_stager_client'

module VCAP::CloudController::Diego
  RSpec.describe StagerClient do
    let(:staging_guid) { 'staging-guid' }
    let(:bbs_client) { instance_double(::Diego::Client, desire_task: ::Diego::Bbs::Models::TaskResponse.new) }

    subject(:client) { BbsStagerClient.new(bbs_client) }

    describe '#stage' do
      let(:staging_message) { instance_double(::Diego::Bbs::Models::TaskDefinition) }

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
            ::Diego::Bbs::Models::TaskResponse.new(
              error: ::Diego::Bbs::Models::Error.new(
                type: ::Diego::Bbs::Models::Error::Type::InvalidRecord,
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
  end
end
