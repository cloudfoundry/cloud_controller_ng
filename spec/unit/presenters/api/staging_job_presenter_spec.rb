require 'spec_helper'
require 'presenters/api/staging_job_presenter'

RSpec.describe StagingJobPresenter do
  describe '#to_hash' do
    let(:job) do
      job = Delayed::Job.enqueue double(:obj, perform: nil)
      allow(job).to receive(:run_at) { Time.now.utc.months_since(1) }
      job
    end

    let(:user) { TestConfig.config[:staging][:auth][:user] }
    let(:password) { TestConfig.config[:staging][:auth][:password] }
    let(:expected_polling_url) do
      "http://#{user}:#{password}@#{TestConfig.config[:internal_service_hostname]}:#{TestConfig.config[:external_port]}/staging/jobs/#{job.guid}"
    end

    it 'creates a valid JSON with the http internal URL' do
      expect(StagingJobPresenter.new(job, 'http').to_hash).to eq(
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

    context 'when temporary_cc_uploader_mtls is true' do
      before do
        TestConfig.load({
          diego: {
            temporary_cc_uploader_mtls: true,
          }
        })
      end

      let(:expected_polling_url) do
        "https://#{TestConfig.config[:internal_service_hostname]}:#{TestConfig.config[:tls_port]}/internal/v4/staging_jobs/#{job.guid}"
      end

      it 'creates a valid JSON with the https internal URL' do
        expect(StagingJobPresenter.new(job, 'https').to_hash).to eq(
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
end
