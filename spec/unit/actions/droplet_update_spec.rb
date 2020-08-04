require 'spec_helper'
require 'actions/droplet_delete'

module VCAP::CloudController
  RSpec.describe DropletUpdate do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user@example.com', user_guid: user.guid) }

    subject(:droplet_update) { DropletUpdate.new }

    describe '#update' do
      context 'buildpack droplet update' do
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
        context 'trying to update a buildpack droplet image' do
          let(:message) do
            VCAP::CloudController::DropletUpdateMessage.new({
              image: 'some-image-reference',
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
          it 'returns an error saying that a buildpack droplet image cannot be updated' do
            expect(message).to be_valid
            expect { droplet_update.update(droplet, message)
            }.to raise_error(DropletUpdate::InvalidDroplet, 'Images can only be updated for docker droplets')
          end
        end
      end
      context 'docker droplet update' do
        let!(:docker_droplet) do
          VCAP::CloudController::DropletModel.make(:kpack)
        end

        let(:message) do
          VCAP::CloudController::DropletUpdateMessage.new({
            image: 'new-image-reference'
          })
        end
        context 'the image of a staged docker droplet is requested to be updated' do
          before do
            docker_droplet.update(docker_receipt_image: 'some-image-reference')
          end
          it 'updates the droplet record with new image reference' do
            expect(message).to be_valid
            updated_droplet = droplet_update.update(docker_droplet, message)
            expect(updated_droplet.docker_receipt_image).to eq 'new-image-reference'
          end
        end
        context 'the image of a staging docker droplet is requested to be updated' do
          before do
            docker_droplet.update(state: VCAP::CloudController::DropletModel::STAGING_STATE)
          end
          it 'returns an error saying that a droplet update cannot occur during staging' do
            expect(message).to be_valid
            expect { droplet_update.update(docker_droplet, message)
            }.to raise_error(DropletUpdate::InvalidDroplet, 'Droplet image cannot be updated during staging')
          end
        end
      end
    end
  end
end
