require 'spec_helper'
require 'actions/droplet_delete'

module VCAP::CloudController
  RSpec.describe DropletUpdate do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user@example.com', user_guid: user.guid) }

    subject(:droplet_update) { DropletUpdate.new }

    describe '#update' do
      let!(:droplet) { DropletModel.make }

      let!(:label) do
        VCAP::CloudController::DropletLabelModel.make(
          key_prefix: 'indiana.edu',
          key_name: 'state',
          value: 'Indiana',
          resource_guid: droplet.guid
        )
      end

      let(:message) do
        VCAP::CloudController::DropletUpdateMessage.new({
          metadata: {
            labels: {
              freaky: 'wednesday',
              'indiana.edu/state' => nil,
            },
          },
        })
      end

      it 'update the droplet record' do
        updated_droplet = droplet_update.update(droplet, message)

        expect(updated_droplet.labels.first.key_name).to eq 'freaky'
        expect(updated_droplet.labels.first.value).to eq 'wednesday'
      end
    end
  end
end
