require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Jobs', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }

  authenticated_request

  get '/v2/jobs/:guid' do
    class FakeJob
      def perform
        # NOOP
      end

      def job_name_in_configuration
        :fake_job
      end

      def max_attempts
        2
      end

      def reschedule_at(time, attempts)
        Time.now + 5
      end
    end

    before { Delayed::Job.delete_all }

    field :guid, 'The guid of the job.', required: false
    field :status, 'The status of the job.', required: false, readonly: true, valid_values: %w(failed finished queued running)

    class KnownFailingJob < FakeJob
      def perform
        raise VCAP::Errors::ApiError.new_from_details('MessageParseError', 'arbitrary string')
      end
    end

    describe 'When a job has failed with a known failure from v2.yml' do
      before { VCAP::CloudController::Jobs::Enqueuer.new(KnownFailingJob.new).enqueue }

      example 'Retrieve Job with known failure' do
        guid = Delayed::Job.last.guid
        Delayed::Worker.new.work_off

        client.get "/v2/jobs/#{guid}", {}, headers
        expect(status).to eq 200
        expect(parsed_response).to include('entity')
        expect(parsed_response['entity']).to include('error')
        expect(parsed_response['entity']['error']).to match(/deprecated/i)

        expect(parsed_response['entity']).to include('error_details')
        expect(parsed_response['entity']['error_details']).to include('code')
        expect(parsed_response['entity']['error_details']).to include('description')
        expect(parsed_response['entity']['error_details']).to include('error_code')

        expect(parsed_response['entity']['error_details']['code']).to eq(1001)
        expect(parsed_response['entity']['error_details']['description']).to match(/arbitrary string/)
        expect(parsed_response['entity']['error_details']['error_code']).to eq('CF-MessageParseError')
      end
    end

    describe 'When a job has failed with an unknown failure' do
      class UnknownFailingJob < FakeJob
        def perform
          raise RuntimeError.new('arbitrary string')
        end
      end

      before { VCAP::CloudController::Jobs::Enqueuer.new(UnknownFailingJob.new).enqueue }

      example 'Retrieve Job with unknown failure' do
        job_last = Delayed::Job.last
        guid = job_last.guid
        Delayed::Worker.new.work_off

        client.get "/v2/jobs/#{guid}", {}, headers
        expect(status).to eq 200
        expect(parsed_response).to include('entity')
        expect(parsed_response['entity']).to include('error')
        expect(parsed_response['entity']['error']).to match(/deprecated/i)

        expect(parsed_response['entity']).to include('error_details')
        expect(parsed_response['entity']['error_details']).to include('code')
        expect(parsed_response['entity']['error_details']).to include('description')
        expect(parsed_response['entity']['error_details']).to include('error_code')

        expect(parsed_response['entity']['error_details']['code']).to eq(10001)
        expect(parsed_response['entity']['error_details']['description']).to eq('An unknown error occurred.')
        expect(parsed_response['entity']['error_details']['error_code']).to eq('UnknownError')
      end
    end

    describe 'For a queued job' do
      class SuccessfulJob < FakeJob; end

      before { VCAP::CloudController::Jobs::Enqueuer.new(SuccessfulJob.new).enqueue }

      example 'Retrieve Job that is queued' do
        guid = Delayed::Job.last.guid

        client.get "/v2/jobs/#{guid}", {}, headers
        expect(status).to eq 200
        expect(parsed_response).to include('entity')
        expect(parsed_response['entity']).to include('status')
        expect(parsed_response['entity']['status']).to eq('queued')
      end
    end

    describe 'For a successfully executed job' do
      class SuccessfulJob < FakeJob; end

      before { VCAP::CloudController::Jobs::Enqueuer.new(SuccessfulJob.new).enqueue }

      example 'Retrieve Job that was successful' do
        guid = Delayed::Job.last.guid
        Delayed::Worker.new.work_off

        client.get "/v2/jobs/#{guid}", {}, headers
        expect(status).to eq 200
        expect(parsed_response).to include('entity')
        expect(parsed_response['entity']).to include('status')
        expect(parsed_response['entity']['status']).to eq('finished')
      end
    end
  end
end
