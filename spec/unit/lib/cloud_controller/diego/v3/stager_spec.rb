require 'spec_helper'
require 'cloud_controller/diego/v3/stager'
require 'cloud_controller/diego/v3/messenger'
require 'cloud_controller/diego/v3/buildpack/staging_completion_handler'

module VCAP::CloudController
  module Diego
    module V3
      RSpec.describe Stager do
        let(:messenger) { instance_double(Diego::V3::Messenger) }
        let(:protocol) { instance_double(Diego::V3::Protocol::PackageStagingProtocol) }
        let(:package) { PackageModel.make }
        let(:config) { TestConfig.config }
        let(:lifecycle_type) { 'buildpack' }

        subject(:stager) do
          Stager.new(package, lifecycle_type, config)
        end

        before do
          allow(Diego::V3::Protocol::PackageStagingProtocol).to receive(:new).with(lifecycle_type).and_return(protocol)
          allow(Diego::V3::Messenger).to receive(:new).with(protocol).and_return(messenger)
        end

        describe '#stage' do
          let(:staging_memory_in_mb) { 1024 }
          let(:staging_disk_in_mb) { 1024 }
          let(:droplet) { DropletModel.make(environment_variables: environment_variables, package_guid: package.guid) }
          let(:environment_variables) { { 'nightshade_vegetable' => 'potato' } }
          let(:staging_details) do
            details                       = VCAP::CloudController::Diego::V3::StagingDetails.new
            details.droplet               = droplet
            details.environment_variables = environment_variables
            details.staging_memory_in_mb  = staging_memory_in_mb
            details.staging_disk_in_mb    = staging_disk_in_mb
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
              allow(messenger).to receive(:send_stage_request).and_raise(CloudController::Errors::ApiError.new_from_details('StagerError', 'staging failed'))
              allow(stager).to receive(:staging_complete)
            end

            it 'calls the completion handler with the error' do
              expect {
                stager.stage(staging_details)
              }.to raise_error(CloudController::Errors::ApiError)
              package.reload
              expect(stager).to have_received(:staging_complete).with(droplet, error)
            end
          end
        end

        describe '#staging_complete' do
          let(:droplet) { instance_double(DropletModel) }
          let(:staging_response) { {} }
          let(:buildpack_completion_handler) { instance_double(Diego::V3::Buildpack::StagingCompletionHandler) }
          let(:docker_completion_handler) { instance_double(Diego::V3::Docker::StagingCompletionHandler) }

          before do
            allow(Diego::V3::Buildpack::StagingCompletionHandler).to receive(:new).with(droplet).and_return(buildpack_completion_handler)
            allow(Diego::V3::Docker::StagingCompletionHandler).to receive(:new).with(droplet).and_return(docker_completion_handler)
            allow(buildpack_completion_handler).to receive(:staging_complete)
            allow(docker_completion_handler).to receive(:staging_complete)
          end

          context 'buildpack' do
            let(:lifecycle_type) { 'buildpack' }

            it 'delegates to a buildpack staging completion handler' do
              stager.staging_complete(droplet, staging_response)
              expect(buildpack_completion_handler).to have_received(:staging_complete).with(staging_response)
              expect(docker_completion_handler).not_to have_received(:staging_complete)
            end
          end

          context 'docker' do
            let(:lifecycle_type) { 'docker' }

            it 'delegates to a docker staging completion handler' do
              stager.staging_complete(droplet, staging_response)
              expect(buildpack_completion_handler).not_to have_received(:staging_complete)
              expect(docker_completion_handler).to have_received(:staging_complete).with(staging_response)
            end
          end
        end
      end
    end
  end
end
