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

            describe 'experimental v2 app docker credential support' do
              it 'does not set docker credentials if there is no web process' do
                message = lifecycle_protocol.lifecycle_data(staging_details)
                expect(message[:docker_login_server]).to be_nil
                expect(message[:docker_user]).to be_nil
                expect(message[:docker_password]).to be_nil
                expect(message[:docker_email]).to be_nil
              end

              it 'does not set docker credentials if the web process has no docker credentials' do
                App.make(app: droplet.app, type: 'web', docker_credentials_json: nil)

                message = lifecycle_protocol.lifecycle_data(staging_details)
                expect(message[:docker_login_server]).to be_nil
                expect(message[:docker_user]).to be_nil
                expect(message[:docker_password]).to be_nil
                expect(message[:docker_email]).to be_nil
              end

              it 'sets docker credentials if the web process has docker credentials' do
                App.make(
                  app:                     droplet.app,
                  type:                    'web',
                  docker_credentials_json: {
                    docker_login_server: 'login-server',
                    docker_user:         'user',
                    docker_password:     'password',
                    docker_email:        'email',
                  }
                )

                message = lifecycle_protocol.lifecycle_data(staging_details)
                expect(message[:docker_login_server]).to eq('login-server')
                expect(message[:docker_user]).to eq('user')
                expect(message[:docker_password]).to eq('password')
                expect(message[:docker_email]).to eq('email')
              end
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
