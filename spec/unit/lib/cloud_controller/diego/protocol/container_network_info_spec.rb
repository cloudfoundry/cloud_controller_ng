require 'spec_helper'

module VCAP::CloudController
  module Diego
    class Protocol
      RSpec.describe ContainerNetworkInfo do
        subject(:container_info) { ContainerNetworkInfo.new(process).to_h }
        let(:process) { AppFactory.make(diego: true) }

        it 'returns the container network information hash' do
          expect(container_info).to eq({
            'properties' => {
              'policy_group_id' => process.guid,
              'app_id' => process.guid,
              'space_id' => process.space.guid,
              'org_id' => process.organization.guid,
            },
          })
        end
      end
    end
  end
end
