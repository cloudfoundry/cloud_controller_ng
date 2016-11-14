require 'spec_helper'
require 'cloud_controller/diego/bbs_task_client'

module VCAP::CloudController::Diego
  RSpec.describe BbsTaskClient do
    let(:task_guid) { 'task-guid' }
    let(:domain) { 'foobar-domain' }
    let(:bbs_client) { instance_double(::Diego::Client) }

    subject(:client) { BbsTaskClient.new(bbs_client) }

    describe '#desire_task' do
      let(:task_definition) { instance_double(::Diego::Bbs::Models::TaskDefinition) }

      before do
        allow(bbs_client).to receive(:desire_task).and_return(::Diego::Bbs::Models::TaskLifecycleResponse.new)
      end

      it 'desires a task' do
        client.desire_task(task_guid, task_definition, domain)

        expect(bbs_client).to have_received(:desire_task).with(task_definition: task_definition, task_guid: task_guid, domain: 'foobar-domain')
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:desire_task).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.desire_task(task_guid, task_definition, domain)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('TaskWorkersUnavailable')
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
            client.desire_task(task_guid, task_definition, domain)
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('TaskError')
          end
        end
      end
    end

    describe '#cancel_task' do
    end
  end
end
