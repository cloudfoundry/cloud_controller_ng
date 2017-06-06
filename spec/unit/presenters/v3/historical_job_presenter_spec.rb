require 'spec_helper'
require 'presenters/v3/historical_job_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe HistoricalJobPresenter do
    let(:job) { VCAP::CloudController::HistoricalJobModel.make(
      state:         VCAP::CloudController::HistoricalJobModel::COMPLETE_STATE,
      operation:     'app.delete',
      resource_guid: 'app-guid',
      resource_type: 'app',
    )
    }
    let(:result) { HistoricalJobPresenter.new(job).to_hash }

    describe '#to_hash' do
      it 'presents the job as json' do
        links = {
          self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" }
        }

        expect(result[:operation]).to eq('app.delete')
        expect(result[:state]).to eq(VCAP::CloudController::HistoricalJobModel::COMPLETE_STATE)
        expect(result[:links]).to eq(links)
      end

      context 'when the job has not completed' do
        before do
          job.update(state: VCAP::CloudController::HistoricalJobModel::PROCESSING_STATE)
        end

        it 'shows the resource link when the jobs resource_type is defined' do
          links = {
            self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" },
            app:  { href: "#{link_prefix}/v3/apps/app-guid" }
          }

          expect(result[:links]).to eq(links)
        end

        it 'does not show the resource link when the jobs resource_type is undefined' do
          job.update(resource_type: nil)
          result = HistoricalJobPresenter.new(job).to_hash
          links  = {
            self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" }
          }

          expect(result[:links]).to eq(links)
        end
      end

      context 'when the job has completed' do
        it 'should not show the resource link' do
          links = {
            self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" }
          }

          expect(result[:links]).to eq(links)
        end
      end
    end
  end
end
