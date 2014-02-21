require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Jobs", type: :api do
  get "/v2/jobs/:guid" do
    class FakeJob
      def perform
        # NOOP
      end

      def job_name_in_configuration
        :fake_job
      end
    end

    before { Delayed::Job.delete_all }

    field :guid, "The guid of the job.", required: false
    field :status, "The status of the job.", required: false, readonly: true, valid_values: %w[failed finished queued running]

    describe "When a legacy job has failed without storing the failure" do
      class KnownFailingJob < FakeJob
        def perform
          raise VCAP::Errors::MessageParseError, "arbitrary string"
        end
      end

      before { VCAP::CloudController::Jobs::Enqueuer.new(KnownFailingJob.new).enqueue }

      example "Retrieve Job Error message" do
        explanation "This is an unauthenticated access to get the job's error status with specified guid."

        Delayed::Worker.new.work_off

        last_job = Delayed::Job.last
        last_job.cf_api_error = nil
        expect(last_job.save).to be_true

        guid = last_job.guid

        client.get "/v2/jobs/#{guid}"
        expect(status).to eq 200
        expect(parsed_response).to include("entity")
        expect(parsed_response["entity"]).to include("error")
        expect(parsed_response["entity"]["error"]).to match(/deprecated/i)

        expect(parsed_response["entity"]).to include("error_details")
        expect(parsed_response["entity"]["error_details"]).to eq("error_code" => "UnknownError",
                                                                 "description" => "An unknown error occurred.",
                                                                 "code" => 10001)
      end
    end


    describe "When a job has failed with a known failure from v2.yml" do
      class KnownFailingJob < FakeJob
        def perform
          raise VCAP::Errors::MessageParseError.new("arbitrary string")
        end
      end

      before { VCAP::CloudController::Jobs::Enqueuer.new(KnownFailingJob.new).enqueue }

      example "Retrieve Job Error message" do
        explanation "This is an unauthenticated access to get the job's error status with specified guid."

        guid = Delayed::Job.last.guid
        Delayed::Worker.new.work_off

        client.get "/v2/jobs/#{guid}"
        expect(status).to eq 200
        expect(parsed_response).to include("entity")
        expect(parsed_response["entity"]).to include("error")
        expect(parsed_response["entity"]["error"]).to match(/deprecated/i)

        expect(parsed_response["entity"]).to include("error_details")
        expect(parsed_response["entity"]["error_details"]).to include("code")
        expect(parsed_response["entity"]["error_details"]).to include("description")
        expect(parsed_response["entity"]["error_details"]).to include("error_code")

        expect(parsed_response["entity"]["error_details"]["code"]).to eq(1001)
        expect(parsed_response["entity"]["error_details"]["description"]).to match(/arbitrary string/)
        expect(parsed_response["entity"]["error_details"]["error_code"]).to eq("CF-MessageParseError")
      end
    end

    describe "When a job has failed with an unknown failure" do
      class UnknownFailingJob < FakeJob
        def perform
          raise RuntimeError.new("arbitrary string")
        end
      end

      before { VCAP::CloudController::Jobs::Enqueuer.new(UnknownFailingJob.new).enqueue }

      example "Retrieve Job Error message" do
        explanation "This is an unauthenticated access to get the job's error status with specified guid."

        job_last = Delayed::Job.last
        guid = job_last.guid
        Delayed::Worker.new.work_off

        client.get "/v2/jobs/#{guid}"
        expect(status).to eq 200
        expect(parsed_response).to include("entity")
        expect(parsed_response["entity"]).to include("error")
        expect(parsed_response["entity"]["error"]).to match(/deprecated/i)

        expect(parsed_response["entity"]).to include("error_details")
        expect(parsed_response["entity"]["error_details"]).to include("code")
        expect(parsed_response["entity"]["error_details"]).to include("description")
        expect(parsed_response["entity"]["error_details"]).to include("error_code")

        expect(parsed_response["entity"]["error_details"]["code"]).to eq(10001)
        expect(parsed_response["entity"]["error_details"]["description"]).to eq("An unknown error occurred.")
        expect(parsed_response["entity"]["error_details"]["error_code"]).to eq("UnknownError")
      end
    end


    describe "For a queued job" do
      class SuccessfulJob < FakeJob; end

      before { VCAP::CloudController::Jobs::Enqueuer.new(SuccessfulJob.new).enqueue }

      example "Retrieve the Job " do
        explanation "This is an unauthenticated access to get the job's status with specified guid."

        guid = Delayed::Job.last.guid

        client.get "/v2/jobs/#{guid}"
        expect(status).to eq 200
        expect(parsed_response).to include("entity")
        expect(parsed_response["entity"]).to include("status")
        expect(parsed_response["entity"]["status"]).to eq("queued")
      end
    end

    describe "For a successfully executed job" do
      class SuccessfulJob < FakeJob; end

      before { VCAP::CloudController::Jobs::Enqueuer.new(SuccessfulJob.new).enqueue }

      example "Retrieve the Job" do
        explanation "This is an unauthenticated access to get the job's status with specified guid."

        guid = Delayed::Job.last.guid
        Delayed::Worker.new.work_off

        client.get "/v2/jobs/#{guid}"
        expect(status).to eq 200
        expect(parsed_response).to include("entity")
        expect(parsed_response["entity"]).to include("status")
        expect(parsed_response["entity"]["status"]).to eq("finished")
      end
    end
  end
end
