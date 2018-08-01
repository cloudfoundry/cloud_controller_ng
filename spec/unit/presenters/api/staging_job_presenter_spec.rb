require 'spec_helper'
require 'presenters/api/staging_job_presenter'

RSpec.describe StagingJobPresenter do
  describe '#to_hash' do
    let(:job) do
      job = Delayed::Job.enqueue double(:obj, perform: nil)
      allow(job).to receive(:run_at) { Time.now.utc.months_since(1) }
      job
    end

    it 'creates a valid JSON with the correct url' do
      user = TestConfig.config[:staging][:auth][:user]
      password = TestConfig.config[:staging][:auth][:password]
      polling_url = "http://#{user}:#{password}@#{TestConfig.config[:external_domain]}/staging/jobs/#{job.guid}"

      expect(StagingJobPresenter.new(job).to_hash).to eq(
        metadata: {
          guid: job.guid,
          created_at: job.created_at.iso8601,
          url: polling_url
        },
        entity: {
          guid: job.guid,
          status: 'queued'
        }
      )
    end
  end
end
