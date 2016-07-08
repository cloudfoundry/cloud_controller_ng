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
              let(:package) { PackageModel.make(:docker, docker_image: 'registry/image-name:latest') }
              let(:droplet) { DropletModel.make(package_guid: package.guid) }
              let(:staging_details) do
                Diego::V3::StagingDetails.new.tap do |details|
                  details.droplet               = droplet
                  details.lifecycle             = instance_double(VCAP::CloudController::DockerLifecycle)
                end
              end

              it 'returns lifecycle data of type docker' do
                type = lifecycle_protocol.lifecycle_data(package, staging_details)[0]
                expect(type).to eq('docker')
              end

              it 'sets the docker image' do
                message = lifecycle_protocol.lifecycle_data(package, staging_details)[1]
                expect(message[:docker_image]).to eq('registry/image-name:latest')
              end
            end
          end
        end
      end
    end
  end
end
