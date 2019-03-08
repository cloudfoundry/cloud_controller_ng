require 'spec_helper'
require 'actions/droplet_delete'

module VCAP::CloudController
  RSpec.describe DropletUpdate do
    let(:user) { FactoryBot.create(:user) }
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

      let!(:annotation) do
        VCAP::CloudController::DropletAnnotationModel.make(
          key: 'University',
          value: 'Toronto',
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
            annotations: {
              reason: 'add some more annotations',
            },
          },
        })
      end

      it 'update the droplet record' do
        expect(message).to be_valid
        updated_droplet = droplet_update.update(droplet, message)

        expect(updated_droplet.labels.first.key_name).to eq 'freaky'
        expect(updated_droplet.labels.first.value).to eq 'wednesday'
        expect(updated_droplet.labels.size).to eq 1
        expect(updated_droplet.annotations.size).to eq(2)
        expect(Hash[updated_droplet.annotations.map { |a| [a.key, a.value] }]).
          to eq({ 'University' => 'Toronto', 'reason' => 'add some more annotations' })
      end
    end
  end
end
