require 'spec_helper'
require 'presenters/v3/historical_job_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe HistoricalJobPresenter do
    let(:job) do
      VCAP::CloudController::HistoricalJobModel.make
    end

    describe '#to_hash' do
      let(:result) { HistoricalJobPresenter.new(job).to_hash }

      it 'presents the job as json' do
        links = {
          self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" }
        }

        expect(result[:operation]).to eq(job.operation)
        expect(result[:state]).to eq(job.state)
        expect(result[:links]).to eq(links)
      end
    end
  end
end
