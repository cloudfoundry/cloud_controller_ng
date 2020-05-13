require 'spec_helper'

module VCAP::CloudController
  module Diego
    class Protocol
      RSpec.describe ContainerNetworkInfo do
        let(:app) { AppModel.make }
        let!(:web_process) { ProcessModel.make(app: app, type: 'web') }
        let!(:deploying_web_process) { ProcessModel.make(app: app, type: 'web') }
        let!(:other_process) { ProcessModel.make(app: app, ports: [8765], type: 'meow') }
        let!(:no_exposed_port_process) { ProcessModel.make(app: app, type: 'woof') }
        let!(:docker_process) { ProcessModelFactory.make(app: app, type: 'docker', ports: [1111, 2222]) }
        let(:ports_str) { '1111,2222,8080,8765' }
        let(:container_workload) { 'im-an-app!' }

        subject(:container_info) { ContainerNetworkInfo.new(app, container_workload) }

        describe '#to_h' do
          it 'returns the container network information hash' do
            expect(container_info.to_h).to eq({
              'properties' => {
                'policy_group_id' => app.guid,
                'app_id' => app.guid,
                'space_id' => app.space.guid,
                'org_id' => app.organization.guid,
                'ports' => ports_str,
                'container_workload' => container_workload
              },
            })
          end
        end

        describe '#to_bbs_network' do
          it 'returns the BBS network object' do
            expect(container_info.to_bbs_network).to eq(
              ::Diego::Bbs::Models::Network.new(
                properties: {
                  'policy_group_id'    => app.guid,
                  'app_id'             => app.guid,
                  'space_id'           => app.space.guid,
                  'org_id'             => app.organization.guid,
                  'ports'              => ports_str,
                  'container_workload' => container_workload,
                }
              )
            )
          end
        end
      end
    end
  end
end
