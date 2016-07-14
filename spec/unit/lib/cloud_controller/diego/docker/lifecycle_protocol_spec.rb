require 'spec_helper'
require 'cloud_controller/diego/docker/lifecycle_protocol'
require_relative '../lifecycle_protocol_shared'

module VCAP
  module CloudController
    module Diego
      module Docker
        RSpec.describe LifecycleProtocol do
          subject(:lifecycle_protocol) { LifecycleProtocol.new }

          it_behaves_like 'a lifecycle protocol' do
            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(:docker, app: app) }
            let(:droplet) { DropletModel.make(:staged, package: package, app: app) }
            let(:process) { App.make(app: app) }

            before do
              app.update(droplet_guid: droplet.guid)
            end

            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.droplet   = droplet
                details.package   = package
                details.lifecycle = instance_double(VCAP::CloudController::DockerLifecycle)
              end
            end
          end

          describe '#lifecycle_data' do
            let(:package) { PackageModel.make(:docker, docker_image: 'registry/image-name:latest') }
            let(:droplet) { DropletModel.make(package_guid: package.guid) }
            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.droplet   = droplet
                details.package   = package
                details.lifecycle = instance_double(VCAP::CloudController::DockerLifecycle)
              end
            end

            it 'sets the docker image' do
              message = lifecycle_protocol.lifecycle_data(staging_details)
              expect(message[:docker_image]).to eq('registry/image-name:latest')
            end
          end

          describe '#desired_app_message' do
            let(:app) { AppModel.make }
            let(:droplet) { DropletModel.make(:docker, state: DropletModel::STAGED_STATE, app: app, docker_receipt_image: 'the-image') }
            let(:process) { App.make(app: app, diego: true, command: 'go go go', metadata: {}) }

            before do
              app.update(droplet_guid: droplet.guid)
            end

            it 'sets the start command' do
              message = lifecycle_protocol.desired_app_message(process)
              expect(message['start_command']).to eq('go go go')
            end

            it 'uses the droplet receipt image' do
              message = lifecycle_protocol.desired_app_message(process)
              expect(message['docker_image']).to eq('the-image')
            end
          end
        end
      end
    end
  end
end
