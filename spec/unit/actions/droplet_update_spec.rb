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

          expect(updated_droplet).to have_labels({ key: 'freaky', value: 'wednesday' })
          expect(updated_droplet).to have_annotations(
            { key: 'University', value: 'Toronto' },
            { key: 'reason', value: 'add some more annotations' }
          )
        end
      end

      context 'image updates' do
        context 'when the droplet is not STAGED' do
          let!(:droplet) { DropletModel.make(:kpack, state: VCAP::CloudController::DropletModel::STAGING_STATE) }

          let(:message) do
            VCAP::CloudController::DropletUpdateMessage.new({
              image: 'new-image-reference'
            })
          end

          it 'returns an error saying that a droplet update cannot occur during staging' do
            expect(message).to be_valid
            expect { droplet_update.update(droplet, message)
            }.to raise_error(DropletUpdate::InvalidDroplet, 'Droplet image can only be updated on staged droplets')
          end
        end

        context 'when the droplet type is buildpack' do
          let!(:droplet) { DropletModel.make(:buildpack) }

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

        context 'when the droplet type is docker' do
          let!(:docker_droplet) do
            VCAP::CloudController::DropletModel.make(:docker)
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
        end
      end
    end
  end
end
