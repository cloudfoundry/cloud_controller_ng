require 'spec_helper'
require 'presenters/api/staging_job_presenter'

RSpec.describe StagingJobPresenter do
  describe '#to_hash' do
    let(:job) do
      job = Delayed::Job.enqueue double(:obj, perform: nil)
      allow(job).to receive(:run_at) { Time.now.utc.months_since(1) }
      job
    end

    let(:expected_polling_url) do
      "https://#{TestConfig.config[:internal_service_hostname]}:#{TestConfig.config[:tls_port]}/internal/v4/staging_jobs/#{job.guid}"
    end

    it 'creates a valid JSON with the https internal URL' do
      expect(StagingJobPresenter.new(job).to_hash).to eq(
        metadata: {
          guid: job.guid,
          created_at: job.created_at.iso8601,
          url: expected_polling_url
        },
        entity: {
          guid: job.guid,
          status: 'queued'
        }
      )
    end
  end
end
