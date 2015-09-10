require 'spec_helper'
require 'cloud_controller/diego/v3/stager'
require 'cloud_controller/diego/v3/messenger'
require 'cloud_controller/diego/traditional/v3/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module V3
      describe Stager do
        let(:messenger) { instance_double(Diego::V3::Messenger) }
        let(:package) { PackageModel.make }
        let(:config) { TestConfig.config }
        let(:completion_handler) do
          instance_double(Diego::Traditional::V3::StagingCompletionHandler)
        end

        subject(:stager) do
          Stager.new(package, messenger, completion_handler, config)
        end

        describe '#stage' do
          let(:stack) { 'cflinuxfs2' }
          let(:memory_limit) { 1024 }
          let(:disk_limit) { 1024 }
          let(:buildpack_info) { 'some-buildpack-info' }
          let(:droplet) { DropletModel.make(environment_variables: environment_variables, package_guid: package.guid) }
          let(:environment_variables) { { 'nightshade_vegetable' => 'potato' } }
          let(:staging_details) do
            details                       = VCAP::CloudController::Diego::Traditional::V3::StagingDetails.new
            details.droplet               = droplet
            details.stack                 = stack
            details.environment_variables = environment_variables
            details.memory_limit          = memory_limit
            details.disk_limit            = disk_limit
            details.buildpack_info        = buildpack_info
            details
          end

          before do
            allow(messenger).to receive(:send_stage_request)
          end

          it 'notifies Diego that the package needs staging' do
            expect(messenger).to receive(:send_stage_request).with(package, config, staging_details)
            stager.stage(staging_details)
          end

          context 'when the stage fails' do
            let(:error) do
              { error: { id: 'StagingError', message: 'Stager error: staging failed' } }
            end

            before do
              allow(messenger).to receive(:send_stage_request).and_raise Errors::ApiError.new_from_details('StagerError', 'staging failed')
              allow(stager).to receive(:staging_complete)
            end

            it 'calls the completion handler with the error' do
              expect {
                stager.stage(staging_details)
              }.to raise_error(Errors::ApiError)
              package.reload
              expect(stager).to have_received(:staging_complete).with(droplet, error)
            end
          end
        end

        describe '#staging_complete' do
          let(:droplet) { instance_double(DropletModel) }
          let(:staging_response) { 'some-response' }

          before do
            allow(completion_handler).to receive(:staging_complete)

            stager.staging_complete(droplet, staging_response)
          end

          it 'delegates to the staging completion handler' do
            expect(completion_handler).to have_received(:staging_complete).with(droplet, staging_response)
          end
        end
      end
    end
  end
end
