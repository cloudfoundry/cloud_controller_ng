require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Jobs", type: :api do
  before do
    job = Class.new do
      def perform
        puts "performing"
      end
    end
    Delayed::Job.enqueue(job.new)
  end

  field :guid, "The guid of the job.", required: false
  field :status, "The status of the job.", required: false, readonly: true, valid_values: %w[failed finished queued running]

  get "/v2/apps/:guid" do
    let(:guid) { Delayed::Job.last.guid }
    example "Retrieve a Particular Job " do
      explanation "This is an unauthenticated access to get the job's status with specified guid."

      client.get "/v2/jobs/#{guid}"
      expect(status).to eq 200
      expect(parsed_response).to include("entity")
      expect(parsed_response["entity"]).to include("status")
    end
  end
end
