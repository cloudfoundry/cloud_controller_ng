require 'spec_helper'

describe JobPresenter do
  describe "#to_hash" do
    let(:job) { Delayed::Job.enqueue double(:obj, perform: nil) }

    it "creates a valid JSON" do
      expect(JobPresenter.new(job).to_hash).to eq(
        metadata: {
          guid: job.id,
          created_at: job.created_at.iso8601,
          url: "/v2/jobs/#{job.id}"
        },
        entity: {
          guid: job.id,
          status: "queued"
        }
      )
    end

    context "when the job has started"
    context "when the job has finished"
    context "when the job has an error"
  end
end