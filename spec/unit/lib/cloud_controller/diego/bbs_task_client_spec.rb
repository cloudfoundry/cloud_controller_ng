require 'spec_helper'
require 'cloud_controller/diego/task_recipe_builder'
require 'cloud_controller/diego/bbs_task_client'

module VCAP::CloudController::Diego
  RSpec.describe BbsTaskClient do
    let(:task) { instance_double(VCAP::CloudController::TaskModel, guid: 'task-guid') }
    let(:config) { instance_double(VCAP::CloudController::Config) }
    let(:domain) { 'foobar-domain' }
    let(:bbs_client) { instance_double(::Diego::Client) }
    let(:recipe_builder) { instance_double(TaskRecipeBuilder) }

    subject(:client) { BbsTaskClient.new(config, bbs_client) }

    describe '#desire_task' do
      let(:task_definition) { instance_double(::Diego::Bbs::Models::TaskDefinition) }

      before do
        allow(bbs_client).to receive(:desire_task).and_return(::Diego::Bbs::Models::TaskLifecycleResponse.new)
        allow(VCAP::CloudController::Diego::TaskRecipeBuilder).to receive(:new).and_return(recipe_builder)
        allow(recipe_builder).to receive(:build_app_task).with(config, task).and_return(task_definition)
      end

      it 'desires a task' do
        client.desire_task(task, domain)

        expect(bbs_client).to have_received(:desire_task).with(task_definition: task_definition, task_guid: task.guid, domain: 'foobar-domain')
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:desire_task).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect do
            client.desire_task(task, domain)
          end.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('TaskWorkersUnavailable')
          end
        end
      end

      context 'when bbs returns a response with an error' do
        before do
          allow(bbs_client).to receive(:desire_task).and_return(
            ::Diego::Bbs::Models::TaskLifecycleResponse.new(
              error: ::Diego::Bbs::Models::Error.new(
                type: ::Diego::Bbs::Models::Error::Type::InvalidRecord,
                message: 'error message'
              )
            )
          )
        end

        it 'raises an api error' do
          expect do
            client.desire_task(task, domain)
          end.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
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
        client.cancel_task(task.guid)
        expect(bbs_client).to have_received(:cancel_task).with(task.guid)
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:cancel_task).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect do
            client.cancel_task(task.guid)
          end.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('TaskWorkersUnavailable')
          end
        end
      end

      context 'when bbs returns a response with an error' do
        before do
          allow(bbs_client).to receive(:cancel_task).and_return(
            ::Diego::Bbs::Models::TaskLifecycleResponse.new(
              error: ::Diego::Bbs::Models::Error.new(
                type: ::Diego::Bbs::Models::Error::Type::InvalidRecord,
                message: 'error message'
              )
            )
          )
        end

        context 'when the task is not in Diego' do
          before do
            allow(bbs_client).to receive(:cancel_task).and_return(
              ::Diego::Bbs::Models::TaskLifecycleResponse.new(
                error: ::Diego::Bbs::Models::Error.new(
                  type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound,
                  message: 'error message'
                )
              )
            )
          end

          it 'succeeds without error' do
            expect do
              client.cancel_task(task.guid)
            end.not_to raise_error
          end
        end

        it 'raises an api error' do
          expect do
            client.cancel_task(task.guid)
          end.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('TaskError')
          end
        end
      end
    end

    describe '#fetch_task' do
      let(:bbs_task) { ::Diego::Bbs::Models::Task.new(task_guid: 'some-task-guid') }
      let(:error) { nil }

      it 'returns the task matching the given guid' do
        expect(bbs_client).to receive(:task_by_guid).with('some-task-guid').
          and_return(::Diego::Bbs::Models::TaskResponse.new(task: bbs_task, error: error))
        expect(client.fetch_task('some-task-guid')).to eq(bbs_task)
      end

      context 'when the bbs returns a response with an error' do
        before do
          error_response = ::Diego::Bbs::Models::TaskResponse.new(
            task: nil,
            error: ::Diego::Bbs::Models::Error.new(message: 'error message')
          )
          allow(bbs_client).to receive(:task_by_guid).and_return(error_response)
        end

        context 'when the task is not in Diego' do
          before do
            allow(bbs_client).to receive(:task_by_guid).and_return(
              ::Diego::Bbs::Models::TaskResponse.new(
                error: ::Diego::Bbs::Models::Error.new(
                  type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound,
                  message: 'error message'
                ),
                task: nil
              )
            )
          end

          it 'returns nil without error' do
            expect do
              fetched_task = client.fetch_task(task.guid)
              expect(fetched_task).to be_nil
            end.not_to raise_error
          end
        end

        it 'raises an api error' do
          expect do
            client.fetch_task('some-task-guid')
          end.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('TaskError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:task_by_guid).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect do
            client.fetch_task('some-task-guid')
          end.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('TaskWorkersUnavailable')
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
          expect do
            client.fetch_tasks
          end.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('TaskError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:tasks).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect do
            client.fetch_tasks
          end.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('TaskWorkersUnavailable')
          end
        end
      end
    end

    describe '#bump_freshness' do
      let(:bbs_response) { ::Diego::Bbs::Models::UpsertDomainResponse.new(error:) }
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
          expect do
            client.bump_freshness
          end.to raise_error(CloudController::Errors::ApiError, /error message/) do |e|
            expect(e.name).to eq('TaskError')
          end
        end
      end

      context 'when bbs client errors' do
        before do
          allow(bbs_client).to receive(:upsert_domain).and_raise(::Diego::Error.new('boom'))
        end

        it 'raises an api error' do
          expect do
            client.bump_freshness
          end.to raise_error(CloudController::Errors::ApiError, /boom/) do |e|
            expect(e.name).to eq('TaskWorkersUnavailable')
          end
        end
      end
    end
  end
end
