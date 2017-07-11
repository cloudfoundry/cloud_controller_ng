require 'spec_helper'
require 'presenters/v3/job_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe JobPresenter do
    shared_examples_for(JobPresenter) do
      let(:job) do
        VCAP::CloudController::PollableJobModel.make(
          state: VCAP::CloudController::PollableJobModel::COMPLETE_STATE,
          operation: "#{resource_type}.delete",
          resource_type: resource_type,
          resource_guid: 'guid',
        )
      end
      let(:result) { JobPresenter.new(job).to_hash }

      describe '#to_hash' do
        it 'presents the job as json' do
          links = {
            self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" }
          }

          expect(result[:operation]).to eq("#{resource_type}.delete")
          expect(result[:state]).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
          expect(result[:links]).to eq(links)
        end

        context 'when the job has not completed' do
          before do
            job.update(state: VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
          end

          it 'shows the resource link when the jobs resource_type is defined' do
            links = {
              self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" },
              "#{resource_type}": { href: "#{link_prefix}/v3/#{resource_type}s/guid" }
            }

            expect(result[:links]).to eq(links)
          end

          it 'does not show the resource link when the jobs resource_type is undefined' do
            job.update(resource_type: nil)
            result = JobPresenter.new(job).to_hash
            links = {
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

    context 'for apps' do
      it_behaves_like JobPresenter do
        let(:resource_type) { 'app' }
      end
    end

    context 'for droplets' do
      it_behaves_like JobPresenter do
        let(:resource_type) { 'droplet' }
      end
    end

    context 'for packages' do
      it_behaves_like JobPresenter do
        let(:resource_type) { 'package' }
      end
    end
  end
end
