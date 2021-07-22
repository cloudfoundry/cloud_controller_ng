require 'spec_helper'
require 'membrane'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe TasksCompletionController do
    describe 'POST /internal/v4/tasks/:task_guid/completed' do
      let(:url) { "/internal/v4/tasks/#{task.guid}/completed" }
      let(:task) { TaskModel.make }
      let(:task_response) do
        {
          task_guid: task.guid,
          failed: false,
          failure_reason: '',
          result: '',
          created_at: 1
        }
      end

      it 'returns a 200 and marks the task as succeeded' do
        post url, MultiJson.dump(task_response)

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq '{}'

        expect(task.reload.state).to eq 'SUCCEEDED'
        expect(task.reload.failure_reason).to eq(nil)
      end

      context 'task fails' do
        let(:task_response) do
          {
            task_guid: task.guid,
            failed: true,
            failure_reason: 'just cuz',
            result: '',
            created_at: 1
          }
        end

        it 'marks the task as failed and sets the result message' do
          post url, MultiJson.dump(task_response)

          expect(last_response.status).to eq(200)
          expect(task.reload.state).to eq 'FAILED'
          expect(task.reload.failure_reason).to eq 'just cuz'
        end
      end

      context 'when task does not exist' do
        let(:url) { '/internal/v4/tasks/bogus/completed' }

        it 'response with a 404' do
          post url, MultiJson.dump(task_response)

          expect(last_response.status).to eq(404)
          expect(last_response.body).to match /NotFound/
        end
      end

      context 'when task is already in a completed state at the time the completion callback is evaluated' do
        context 'when task is already succeeded' do
          let(:task) { TaskModel.make(state: 'SUCCEEDED') }

          it 'responds with a 400 status code' do
            post url, MultiJson.dump(task_response)

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/InvalidRequest/)
          end
        end

        context 'when task is already failed' do
          let(:task) { TaskModel.make(state: 'FAILED') }

          it 'responds with a 400 status code' do
            post url, MultiJson.dump(task_response)

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/InvalidRequest/)
          end
        end
      end

      describe 'validation' do
        context 'when sending invalid json' do
          it 'fails with a 400' do
            post url, 'this is not json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/MessageParseError/)
          end
        end

        context 'with an invalid task guid' do
          let(:other_task) { TaskModel.make }
          let(:url) { "/internal/v4/tasks/#{other_task.guid}/completed" }

          it 'fails with a 400' do
            post url, MultiJson.dump(task_response)

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/InvalidRequest/)
          end
        end
      end
    end
  end
end
