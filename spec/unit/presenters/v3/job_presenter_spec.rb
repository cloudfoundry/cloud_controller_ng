require 'spec_helper'
require 'presenters/v3/job_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe JobPresenter do
    shared_examples_for(JobPresenter) do
      let(:api_error) { nil }
      let(:job) do
        create(:pollable_job_model, state: VCAP::CloudController::PollableJobModel::COMPLETE_STATE,
                                    operation: "#{resource_type}.my_async_operation",
                                    resource_type: resource_type,
                                    resource_guid: resource.guid,
                                    cf_api_error: api_error)
      end
      let(:result) { JobPresenter.new(job).to_hash }

      describe '#to_hash' do
        it 'presents the job as json' do
          links = {
            self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" },
            "#{resource_type}": { href: "#{link_prefix}/v3/#{resource_type}s/#{resource.guid}" }
          }

          expect(result[:operation]).to eq("#{resource_type}.my_async_operation")
          expect(result[:state]).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
          expect(result[:links]).to eq(links)
          expect(result[:errors]).to eq([])
          expect(result[:warnings]).to eq([])
        end

        context 'when the job has not completed' do
          before do
            job.update(state: VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
          end

          it 'shows the resource link when the jobs resource_type is defined' do
            links = {
              self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" },
              "#{resource_type}": { href: "#{link_prefix}/v3/#{resource_type}s/#{resource.guid}" }
            }

            expect(result[:links]).to eq(links)
          end
        end

        context 'when the job has completed' do
          it 'stills show the resource link' do
            links = {
              self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" },
              "#{resource_type}": { href: "#{link_prefix}/v3/#{resource_type}s/#{resource.guid}" }
            }

            expect(result[:links]).to eq(links)
          end
        end

        context 'when the resource is deleted' do
          before do
            resource.delete
          end

          it 'does not show the resource link' do
            links = {
              self: { href: "#{link_prefix}/v3/jobs/#{job.guid}" }
            }

            expect(result[:links]).to eq(links)
          end
        end

        context 'when the job has an error' do
          let(:api_error) do
            YAML.dump({
                        'errors' => [{
                          'title' => 'CF-BlobstoreError',
                          'code' => 150_007,
                          'description' => 'Failed to perform blobstore operation after three retries.'
                        }]
                      })
          end

          context 'when the job later completes' do
            before do
              job.update(state: VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            it 'does not present the list of errors' do
              expect(result[:errors]).to be_empty
            end
          end

          context 'when job is processing or failed' do
            before do
              job.update(state: VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
            end

            it 'presents the list of errors' do
              expect(result[:errors]).to eq([{
                                              title: 'CF-BlobstoreError',
                                              code: 150_007,
                                              description: 'Failed to perform blobstore operation after three retries.'
                                            }])
            end
          end
        end

        context 'when the job has a warning' do
          before do
            create(:job_warning_model, job: job, detail: 'warning one')
            create(:job_warning_model, job: job, detail: 'warning two')
          end

          it 'presents the list of warnings' do
            expect(result[:warnings]).to contain_exactly({ detail: 'warning one' }, { detail: 'warning two' })
          end
        end
      end
    end

    context 'for apps' do
      it_behaves_like JobPresenter do
        let(:resource_type) { 'app' }
        let(:resource) { create(:app_model) }
      end
    end

    context 'for buildpacks' do
      it_behaves_like JobPresenter do
        let(:resource_type) { 'buildpack' }
        let(:resource) { create(:buildpack) }
      end
    end

    context 'for droplets' do
      it_behaves_like JobPresenter do
        let(:resource_type) { 'droplet' }
        let(:resource) { create(:droplet_model, app: nil, set_as_current_droplet: false) }
      end
    end

    context 'for packages' do
      it_behaves_like JobPresenter do
        let(:resource_type) { 'package' }
        let(:resource) { create(:package_model) }
      end
    end

    context 'for service brokers' do
      it_behaves_like JobPresenter do
        let(:resource_type) { 'service_broker' }
        let(:resource) { create(:service_broker) }
      end
    end
  end
end
