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
      let(:config) { TestConfig.config_instance }
      let(:build) { BuildModel.make(package_guid: package.guid) }
      let!(:lifecycle_data_model) { BuildpackLifecycleDataModel.make(build: build) }
      let(:environment_variables) { { 'nightshade_vegetable' => 'potato' } }

      let(:buildpack_completion_handler) { instance_double(Diego::Buildpack::StagingCompletionHandler) }
      let(:docker_completion_handler) { instance_double(Diego::Docker::StagingCompletionHandler) }

      before do
        allow(Diego::Buildpack::StagingCompletionHandler).to receive(:new).with(build).and_return(buildpack_completion_handler)
        allow(Diego::Docker::StagingCompletionHandler).to receive(:new).with(build).and_return(docker_completion_handler)
        allow(buildpack_completion_handler).to receive(:staging_complete)
        allow(docker_completion_handler).to receive(:staging_complete)
        allow(Diego::Messenger).to receive(:new).and_return(messenger)
      end

      it_behaves_like 'a stager'

      describe '#stage' do
        let(:staging_memory_in_mb) { 1024 }
        let(:staging_disk_in_mb) { 1024 }
        let(:staging_details) do
          details                       = VCAP::CloudController::Diego::StagingDetails.new
          details.package               = package
          details.environment_variables = environment_variables
          details.staging_memory_in_mb  = staging_memory_in_mb
          details.staging_disk_in_mb    = staging_disk_in_mb
          details.staging_guid          = build.guid
          details.lifecycle             = lifecycle
          details
        end
        let(:lifecycle) do
          LifecycleProvider.provide(package, staging_message)
        end
        let(:request_data) do
          {}
        end
        let(:lifecycle_type) { 'buildpack' }
        let(:staging_message) { BuildCreateMessage.new(lifecycle: { data: request_data, type: lifecycle_type }) }

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
          end

          it 'calls the completion handler with the error' do
            expect {
              stager.stage(staging_details)
            }.to raise_error(CloudController::Errors::ApiError)
            package.reload
            expect(buildpack_completion_handler).to have_received(:staging_complete).with(error, false)
          end
        end
      end

      describe '#staging_complete' do
        let(:staging_response) { {} }

        context 'buildpack' do
          let(:build) { BuildModel.make }
          let!(:lifecycle_data_model) { BuildpackLifecycleDataModel.make(build: build) }

          it 'delegates to a buildpack staging completion handler' do
            stager.staging_complete(build, staging_response)
            expect(buildpack_completion_handler).to have_received(:staging_complete).with(staging_response, boolean)
            expect(docker_completion_handler).not_to have_received(:staging_complete)
          end
        end

        context 'docker' do
          let(:build) { BuildModel.make(:docker) }
          let!(:lifecycle_data_model) { nil }

          it 'delegates to a docker staging completion handler' do
            stager.staging_complete(build, staging_response)
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
