require 'spec_helper'
require 'cloud_controller/diego/v3/docker/lifecycle_protocol'
require_relative '../../lifecycle_protocol_shared'

module VCAP
  module CloudController
    module Diego
      module V3
        module Docker
          RSpec.describe LifecycleProtocol do
            subject(:lifecycle_protocol) { LifecycleProtocol.new }

            it_behaves_like 'a v3 lifecycle protocol' do
              let(:app) { AppModel.make }
              let(:package) { PackageModel.make(:docker, app_guid: app.guid) }
              let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: app.guid) }

              let(:staging_details) do
                Diego::V3::StagingDetails.new.tap do |details|
                  details.droplet               = droplet
                  details.lifecycle             = instance_double(VCAP::CloudController::DockerLifecycle)
                end
              end
            end

            describe '#lifecycle_data' do
              let(:package) { PackageModel.make(:docker) }
              let(:droplet) { DropletModel.make(package_guid: package.guid) }
              let(:staging_details) do
                Diego::V3::StagingDetails.new.tap do |details|
                  details.droplet               = droplet
                  details.lifecycle             = instance_double(VCAP::CloudController::DockerLifecycle)
                end
              end

              before do
                package.docker_data.image = 'registry/image-name:latest'
                package.docker_data.save
              end

              it 'returns lifecycle data of type docker' do
                type = lifecycle_protocol.lifecycle_data(package, staging_details)[0]
                expect(type).to eq('docker')
              end

              it 'sets the docker image' do
                message = lifecycle_protocol.lifecycle_data(package, staging_details)[1]
                expect(message[:docker_image]).to eq('registry/image-name:latest')
              end

              # context 'when there are image credentials' do
              #   let(:server) { 'http://loginServer.com' }
              #   let(:user) { 'user' }
              #   let(:password) { 'password' }
              #   let(:email) { 'email' }
              #   let(:docker_credentials) do
              #     {
              #       docker_login_server: server,
              #       docker_user:         user,
              #       docker_password:     password,
              #       docker_email:        email
              #     }
              #   end
              #   let(:app) { AppFactory.make(docker_image: 'fake/docker_image', docker_credentials_json: docker_credentials, diego: true) }
              #
              #   it 'uses the provided credentials to stage a Docker app' do
              #     message = lifecycle_protocol.lifecycle_data(app)[1]
              #
              #     expect(message[:docker_login_server]).to eq(server)
              #     expect(message[:docker_user]).to eq(user)
              #     expect(message[:docker_password]).to eq(password)
              #     expect(message[:docker_email]).to eq(email)
              #   end
              # end
            end
          end
        end
      end
    end
  end
end
