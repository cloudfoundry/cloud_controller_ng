require 'spec_helper'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  RSpec.describe BulkTasksController do
    def task_table_entry(index)
      TaskModel.order_by(:id).all[index - 1]
    end

    before do
      @internal_user = 'internal_user'
      @internal_password = 'internal_password'

      5.times { |i| TaskModel.make(state: 'RUNNING') }
    end

    describe 'GET', '/internal/v3/bulk/task_states' do
      let(:task_states_endpoint) { '/internal/v3/bulk/task_states' }

      context 'without credentials' do
        it 'rejects the request as unauthorized' do
          get task_states_endpoint
          expect(last_response.status).to eq(401)
        end
      end

      context 'with invalid credentials' do
        before do
          authorize 'bar', 'foo'
        end

        it 'rejects the request as unauthorized' do
          get task_states_endpoint
          expect(last_response.status).to eq(401)
        end
      end

      context 'with valid credentials' do
        before do
          authorize @internal_user, @internal_password
        end

        it 'requires a token in query string' do
          get task_states_endpoint, { 'batch_size' => 20 }

          expect(last_response.status).to eq(400)
        end

        it 'returns a populated token for the initial request (which has an empty bulk token)' do
          get task_states_endpoint, { 'batch_size' => 3,
                                      'token' => '{}' }

          expect(last_response.status).to eq(200)
          expect(decoded_response['token']).to eq({ 'id' => task_table_entry(3).id })
        end

        it 'returns task states in the response body' do
          get task_states_endpoint, { 'batch_size' => 20,
                                      'token' => { id: task_table_entry(2).id }.to_json }

          expect(last_response.status).to eq(200), "Response Body: #{last_response.body}"
          expect(decoded_response['task_states'].size).to eq(3)
        end

        describe 'pagination' do
          it 'respects the batch_size parameter' do
            [3, 5].each { |size|
              get task_states_endpoint, {
                'batch_size' => size,
                'token' => { id: 0 }.to_json,
              }

              expect(last_response.status).to eq(200)
              expect(decoded_response['task_states'].size).to eq(size)
            }
          end

          it 'returns non-intersecting task states when token is supplied' do
            get task_states_endpoint, {
              'batch_size' => 2,
              'token' => { id: 0 }.to_json,
            }

            expect(last_response.status).to eq(200)

            saved_tasks = decoded_response['task_states'].dup
            expect(saved_tasks.size).to eq(2)

            get task_states_endpoint, {
              'batch_size' => 2,
              'token' => MultiJson.dump(decoded_response['token']),
            }

            expect(last_response.status).to eq(200)

            new_tasks = decoded_response['task_states'].dup
            expect(new_tasks.size).to eq(2)
            saved_tasks.each do |saved_result|
              expect(new_tasks).not_to include(saved_result)
            end
          end

          it 'should eventually return entire collection, batch after batch' do
            tasks = []
            total_size = TaskModel.count

            token = '{}'
            while tasks.size < total_size
              get task_states_endpoint, {
                'batch_size' => 2,
                'token' => MultiJson.dump(token),
              }

              expect(last_response.status).to eq(200)
              token = decoded_response['token']
              tasks += decoded_response['task_states']
            end

            expect(tasks.size).to eq(total_size)
            get task_states_endpoint, {
              'batch_size' => 2,
              'token' => MultiJson.dump(token),
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response['task_states'].size).to eq(0)
          end
        end
      end
    end
  end
end
