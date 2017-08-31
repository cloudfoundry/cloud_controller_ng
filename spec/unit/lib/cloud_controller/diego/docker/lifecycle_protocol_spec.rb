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
            let(:droplet) { DropletModel.make(package: package, app: app) }
            let(:process) { ProcessModel.make(app: app) }

            before do
              app.update(droplet_guid: droplet.guid)
            end

            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.staging_guid = droplet.guid
                details.package = package
                details.lifecycle = instance_double(VCAP::CloudController::DockerLifecycle)
              end
            end
          end

          describe '#lifecycle_data' do
            let(:app) { AppModel.make }
            let(:package) do
              PackageModel.make(:docker,
                app:             app,
                docker_image:    'registry/image-name:latest',
                docker_username: 'dockerusername',
                docker_password: 'dockerpassword',)
            end
            let(:droplet) { DropletModel.make(package_guid: package.guid) }
            let(:staging_details) do
              Diego::StagingDetails.new.tap do |details|
                details.staging_guid = droplet.guid
                details.package = package
                details.lifecycle = instance_double(VCAP::CloudController::DockerLifecycle)
              end
            end

            it 'sets the docker image' do
              message = lifecycle_protocol.lifecycle_data(staging_details)
              expect(message[:docker_image]).to eq('registry/image-name:latest')
              expect(message[:docker_user]).to eq('dockerusername')
              expect(message[:docker_password]).to eq('dockerpassword')
            end
          end

          describe '#desired_app_message' do
            let(:app) { AppModel.make }
            let(:droplet) do
              DropletModel.make(:docker,
                                state: DropletModel::STAGED_STATE,
                                app: app,
                                docker_receipt_image: 'the-image',
                                docker_receipt_username: 'dockerusername',
                                docker_receipt_password: 'dockerpassword',
                               )
            end
            let(:process) { ProcessModel.make(app: app, diego: true, command: 'go go go', metadata: {}) }

            before do
              app.update(droplet_guid: droplet.guid)
            end

            it 'sets the start command' do
              message = lifecycle_protocol.desired_app_message(process)
              expect(message['start_command']).to eq('go go go')
            end

            it 'uses the droplet receipt image and docker credentials' do
              message = lifecycle_protocol.desired_app_message(process)
              expect(message['docker_image']).to eq('the-image')
              expect(message['docker_user']).to eq('dockerusername')
              expect(message['docker_password']).to eq('dockerpassword')
            end
          end

          describe '#desired_lrp_builder' do
            let(:config) { Config.new({}) }
            let(:app) { AppModel.make(droplet: droplet) }
            let(:droplet) do
              DropletModel.make(:docker, {
                state: DropletModel::STAGED_STATE,
                docker_receipt_image: 'the-image',
                execution_metadata: 'foobar',
              })
            end
            let(:process) { ProcessModel.make(app: app, diego: true, command: 'go go go', metadata: {}) }
            let(:builder_opts) do
              {
                ports: [1, 2, 3],
                docker_image: 'the-image',
                execution_metadata: 'foobar',
                start_command: 'go go go',
              }
            end
            before do
              allow(Protocol::OpenProcessPorts).to receive(:new).with(process).and_return(
                instance_double(Protocol::OpenProcessPorts, to_a: [1, 2, 3])
              )
            end

            it 'creates a diego DesiredLrpBuilder' do
              expect(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder).to receive(:new).with(
                config,
                builder_opts,
              )
              lifecycle_protocol.desired_lrp_builder(config, process)
            end
          end

          describe '#task_action_builder' do
            let(:config) { Config.new({}) }
            let(:droplet) { DropletModel.make(:docker, docker_receipt_image: 'repository/the-image') }
            let(:task) { TaskModel.make(droplet: droplet) }
            let(:lifecycle_data) do
              {
                droplet_path: 'repository/the-image',
              }
            end

            it 'creates a diego TaskActionBuilder' do
              expect(VCAP::CloudController::Diego::Docker::TaskActionBuilder).to receive(:new).with(
                config,
                task,
                lifecycle_data,
              )
              lifecycle_protocol.task_action_builder(config, task)
            end
          end
        end
      end
    end
  end
end
