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
      before do
        allow(bbs_client).to receive(:cancel_task).and_return(::Diego::Bbs::Models::TaskLifecycleResponse.new)
      end

      it 'cancels the task' do
        client.cancel_task(task_guid)
        expect(bbs_client).to have_received(:cancel_task).with(task_guid)
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:cancel_task).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.cancel_task(task_guid)
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('TaskWorkersUnavailable')
          end
        end
      end

      context 'when bbs returns a response with an error' do
        before do
          allow(bbs_client).to receive(:cancel_task).and_return(
            ::Diego::Bbs::Models::TaskLifecycleResponse.new(
              error: ::Diego::Bbs::Models::Error.new(
                type:    ::Diego::Bbs::Models::Error::Type::InvalidRecord,
                message: 'error message'
              )))
        end

        it 'raises an api error' do
          expect {
            client.cancel_task(task_guid)
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('TaskError')
          end
        end
      end
    end

    describe '#fetch_tasks' do
      let(:bbs_tasks) { [::Diego::Bbs::Models::Task.new] }
      let(:error) { nil }

      before do
        allow(bbs_client).to receive(:tasks).and_return(::Diego::Bbs::Models::TasksResponse.new(tasks: bbs_tasks, error: error))
      end

      it 'returns the fetched list of tasks' do
        expect(client.fetch_tasks).to eq(bbs_tasks)
        expect(bbs_client).to have_received(:tasks).with(domain: TASKS_DOMAIN)
      end

      context 'when the bbs returns a response with an error' do
        let(:error) do
          ::Diego::Bbs::Models::Error.new(message: 'error message')
        end

        it 'raises an api error' do
          expect {
            client.fetch_tasks
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('TaskError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:tasks).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect {
            client.fetch_tasks
          }.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('TaskWorkersUnavailable')
          end
        end
      end
    end

    describe '#bump_freshness' do
      let(:bbs_response) { ::Diego::Bbs::Models::UpsertDomainResponse.new(error: error) }
      let(:error) { nil }

      before do
        allow(bbs_client).to receive(:upsert_domain).with(domain: TASKS_DOMAIN, ttl: TASKS_DOMAIN_TTL).and_return(bbs_response)
      end

      it 'sends the upsert domain to diego' do
        client.bump_freshness
        expect(bbs_client).to have_received(:upsert_domain).with(domain: TASKS_DOMAIN, ttl: TASKS_DOMAIN_TTL)
      end

      context 'when the bbs response contains any other error' do
        let(:error) { ::Diego::Bbs::Models::Error.new(type: ::Diego::Bbs::Models::Error::Type::UnknownError, message: 'error message') }

        it 'raises an api error' do
          expect {
            client.bump_freshness
          }.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('TaskError')
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
            expect(e.name).to eq('TaskWorkersUnavailable')
          end
        end
      end
    end
  end
end
