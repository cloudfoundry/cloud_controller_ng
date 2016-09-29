require 'spec_helper'

module VCAP::CloudController
  module Diego
    class Protocol
      RSpec.describe ContainerNetworkInfo do
        subject(:container_info) { ContainerNetworkInfo.new(process).to_h }
        let(:process) { App.make(app: parent_app) }
        let(:parent_app) { AppModel.make }

        it 'returns the container network information hash' do
          expect(container_info).to eq({
            'properties' => {
              'policy_group_id' => parent_app.guid,
              'app_id' => parent_app.guid,
              'space_id' => parent_app.space.guid,
              'org_id' => parent_app.organization.guid,
            },
          })
        end
      end
    end
  end
end
