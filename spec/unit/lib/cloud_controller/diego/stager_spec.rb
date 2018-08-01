require 'spec_helper'
require 'cloud_controller/diego/stager'
require 'cloud_controller/diego/messenger'
require 'cloud_controller/diego/buildpack/staging_completion_handler'

module VCAP::CloudController
  module Diego
    RSpec.describe Stager do
      subject(:stager) { Stager.new(config) }

      let(:messenger) { instance_double(Diego::Messenger) }
      let(:protocol) { instance_double(Diego::Protocol) }
      let(:package) { PackageModel.make }
      let(:config) { TestConfig.config }

      before do
        allow(Diego::Messenger).to receive(:new).and_return(messenger)
      end

      it_behaves_like 'a stager'

      describe '#stage' do
        let(:staging_memory_in_mb) { 1024 }
        let(:staging_disk_in_mb) { 1024 }
        let(:droplet) { DropletModel.make(environment_variables: environment_variables, package_guid: package.guid) }
        let(:environment_variables) { { 'nightshade_vegetable' => 'potato' } }
        let(:staging_details) do
          details                       = VCAP::CloudController::Diego::StagingDetails.new
          details.droplet               = droplet
          details.package               = package
          details.environment_variables = environment_variables
          details.staging_memory_in_mb  = staging_memory_in_mb
          details.staging_disk_in_mb    = staging_disk_in_mb
          details
        end

        before do
          allow(messenger).to receive(:send_stage_request)
        end

        it 'notifies Diego that the package needs staging' do
          expect(messenger).to receive(:send_stage_request).with(config, staging_details)
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
        let(:buildpack_completion_handler) { instance_double(Diego::Buildpack::StagingCompletionHandler) }
        let(:docker_completion_handler) { instance_double(Diego::Docker::StagingCompletionHandler) }

        before do
          allow(Diego::Buildpack::StagingCompletionHandler).to receive(:new).with(droplet).and_return(buildpack_completion_handler)
          allow(Diego::Docker::StagingCompletionHandler).to receive(:new).with(droplet).and_return(docker_completion_handler)
          allow(buildpack_completion_handler).to receive(:staging_complete)
          allow(docker_completion_handler).to receive(:staging_complete)
        end

        context 'buildpack' do
          let(:droplet) { DropletModel.make }

          it 'delegates to a buildpack staging completion handler' do
            stager.staging_complete(droplet, staging_response)
            expect(buildpack_completion_handler).to have_received(:staging_complete).with(staging_response, boolean)
            expect(docker_completion_handler).not_to have_received(:staging_complete)
          end
        end

        context 'docker' do
          let(:droplet) { DropletModel.make(:docker) }

          it 'delegates to a docker staging completion handler' do
            stager.staging_complete(droplet, staging_response)
            expect(buildpack_completion_handler).not_to have_received(:staging_complete)
            expect(docker_completion_handler).to have_received(:staging_complete).with(staging_response, boolean)
          end
        end
      end

      describe '#stop_stage' do
        before do
          allow(messenger).to receive(:send_stop_staging_request)
        end

        it 'delegates to the messenger' do
          stager.stop_stage('staging-guid')
          expect(messenger).to have_received(:send_stop_staging_request).with('staging-guid')
        end
      end
    end
  end
end
