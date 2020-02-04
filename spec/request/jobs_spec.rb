require 'spec_helper'

RSpec.describe 'Jobs' do
  let(:user) { make_user }
  let(:user_headers) { headers_for(user, email: 'some_email@example.com', user_name: 'Mr. Freeze') }

  describe 'when getting a job that exists' do
    it 'returns a json representation of a generic job' do
      operation = 'app.delete'
      job = VCAP::CloudController::PollableJobModel.make(
        resource_type: 'app',
        state: VCAP::CloudController::PollableJobModel::COMPLETE_STATE,
        operation: operation,
      )
      job_guid = job.guid

      get "/v3/jobs/#{job_guid}", nil, user_headers

      expected_response = {
        'guid' => job_guid,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'operation' => operation,
        'state' => 'COMPLETE',
        'errors' => [],
        'warnings' => [],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/jobs/#{job_guid}" }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'returns a json representation of a special case' do
      operation = 'app.delete'
      job = VCAP::CloudController::PollableJobModel.make(
        resource_type: 'organization_quota',
        state: VCAP::CloudController::PollableJobModel::COMPLETE_STATE,
        operation: operation,
      )
      job_guid = job.guid

      get "/v3/jobs/#{job_guid}", nil, user_headers

      expected_response = {
        'guid' => job_guid,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'operation' => operation,
        'state' => 'COMPLETE',
        'errors' => [],
        'warnings' => [],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/jobs/#{job_guid}" }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'running a pollable job that emits warnings' do
    it 'contains these warnings in the job representation' do
      job = TestJob.new(user.guid)
      pollable_job = VCAP::CloudController::Jobs::Enqueuer.new(job, queue: VCAP::CloudController::Jobs::Queues.generic).enqueue_pollable
      job_guid = pollable_job.guid

      execute_all_jobs(expected_successes: 1, expected_failures: 0)

      get "/v3/jobs/#{job_guid}", nil, user_headers

      expected_response = {
        'guid' => job_guid,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'operation' => 'user.test_job',
        'state' => 'COMPLETE',
        'errors' => [],
        'warnings' => match_array([
          {
            'detail' => 'warning-one'
          },
          {
              'detail' => 'warning-two'
          },
        ]),
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/jobs/#{job_guid}" },
          'users' => { 'href' => "#{link_prefix}/v3/users/#{user.guid}" },
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    class TestJob < VCAP::CloudController::Jobs::CCJob
      def initialize(guid)
        @guid = guid
      end

      def before(delayed_job)
        @delayed_job_guid = delayed_job.guid
      end

      def perform
        pollable_job = VCAP::CloudController::PollableJobModel.find_by_delayed_job_guid(@delayed_job_guid)
        VCAP::CloudController::JobWarningModel.make(detail: 'warning-one', job_id: pollable_job.id)
        VCAP::CloudController::JobWarningModel.make(detail: 'warning-two', job_id: pollable_job.id)
      end

      def job_name_in_configuration
        :test_job
      end

      def max_attempts
        1
      end

      def resource_type
        'users'
      end

      def resource_guid
        @guid
      end

      def display_name
        'user.test_job'
      end
    end
  end
end
