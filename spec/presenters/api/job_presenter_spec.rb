require 'spec_helper'

describe JobPresenter do
  describe "#to_hash" do
    let(:job) do
      job = Delayed::Job.enqueue double(:obj, perform: nil)
      job.stub(:run_at) { Time.now.months_since(1) }
      job
    end

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

    context "when the job has started" do
      let(:job) do
        job = Delayed::Job.enqueue double(:obj, perform: nil)
        job.stub(:run_at) { Time.now.months_since(-1) }
        job
      end

      it "creates a valid JSON" do
        expect(JobPresenter.new(job).to_hash).to eq(
          metadata: {
            guid: job.id,
            created_at: job.created_at.iso8601,
            url: "/v2/jobs/#{job.id}"
          },
          entity: {
            guid: job.id,
            status: "started"
          }
        )
      end
    end

    context "when the job does not exist (i.e. it finished and was deleted)" do
      let(:job) { nil }

      it "creates a valid JSON" do
        expect(JobPresenter.new(job).to_hash).to eq(
          metadata: {
            guid: "0",
            created_at: Time.at(0).iso8601,
            url: "/v2/jobs/0"
          },
          entity: {
            guid: "0",
            status: "finished"
          }
        )
      end
    end

    context "when the job has an error" do
      let(:job) do
        job = Delayed::Job.enqueue double(:obj, perform: nil)
        job.stub(:last_error) { "failed to upload app" }
        job
      end

      it "creates a valid JSON" do
        expect(JobPresenter.new(job).to_hash).to eq(
          metadata: {
            guid: job.id,
            created_at: job.created_at.iso8601,
            url: "/v2/jobs/#{job.id}"
          },
          entity: {
            guid: job.id,
            status: "failed"
          }
        )
      end
    end
  end
end