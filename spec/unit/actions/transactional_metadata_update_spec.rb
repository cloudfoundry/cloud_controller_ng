require 'spec_helper'
require 'actions/transactional_metadata_update'

module VCAP::CloudController
  RSpec.describe TransactionalMetadataUpdate do
    describe '#update' do
      let(:new_metadata) {
        {
          metadata: {
            labels: {
              freaky: 'wednesday'
            },
            annotations: {
              tokyo: 'grapes'
            }
          }
        }
      }
      let(:update_request_body) { new_metadata }
      let(:resource) { Service.make }
      let(:message) { MetadataUpdateMessage.new(update_request_body) }

      context 'when the resource has no metadata' do
        context 'and no metadata is specified' do
          let(:update_request_body) { {} }

          it 'adds no metadata' do
            expect(message).to be_valid
            updated_resource = TransactionalMetadataUpdate.update(resource, message)

            resource.reload

            expect(resource).to eq(updated_resource)
            expect(updated_resource).not_to have_labels
            expect(updated_resource).not_to have_annotations
          end
        end

        it 'adds metadata to a resource' do
          expect(message).to be_valid
          updated_resource = TransactionalMetadataUpdate.update(resource, message)
          expect(updated_resource).to have_labels({ key: 'freaky', value: 'wednesday' })
          expect(updated_resource).to have_annotations({ key: 'tokyo', value: 'grapes' })

          resource.reload
          expect(resource).to eq(updated_resource)
        end
      end

      context 'when the resource has existing metadata' do
        before do
          VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: resource.guid, key_name: 'freaky', value: 'tuesday')
          VCAP::CloudController::ServiceOfferingAnnotationModel.make(resource_guid: resource.guid, key: 'tokyo', value: 'apples')
        end

        context 'and no metadata is specified' do
          let(:update_request_body) { {} }

          it 'does not change the existing values' do
            expect(message).to be_valid
            updated_resource = TransactionalMetadataUpdate.update(resource, message)

            resource.reload

            expect(resource).to eq(updated_resource)
            expect(updated_resource).to have_labels({ key: 'freaky', value: 'tuesday' })
            expect(updated_resource).to have_annotations({ key: 'tokyo', value: 'apples' })
          end
        end

        it 'can add new values' do
          message = MetadataUpdateMessage.new({
            metadata: {
              labels: {
                freaky: 'tuesday',
                another_label: 'new-label',
              },
              annotations: {
                tokyo: 'apples',
                another_annotation: 'new-annotation',
              }
            }
          })

          expect(message).to be_valid
          updated_resource = TransactionalMetadataUpdate.update(resource, message)
          expect(updated_resource).to have_labels(
            { key: 'freaky', value: 'tuesday' },
            { key: 'another_label', value: 'new-label' },
          )
          expect(updated_resource).to have_annotations(
            { key: 'tokyo', value: 'apples' },
            { key: 'another_annotation', value: 'new-annotation' }
          )
        end

        it 'can update existing values' do
          expect(message).to be_valid
          updated_resource = TransactionalMetadataUpdate.update(resource, message)
          expect(updated_resource).to have_labels({ key: 'freaky', value: 'wednesday' })
          expect(updated_resource).to have_annotations({ key: 'tokyo', value: 'grapes' })
        end

        it 'can delete existing values' do
          new_body = {
            metadata: {
              labels: {
                freaky: nil
              },
              annotations: {
                tokyo: nil
              }
            }
          }
          new_message = MetadataUpdateMessage.new(new_body)

          expect(new_message).to be_valid

          updated_resource = TransactionalMetadataUpdate.update(resource, new_message)
          expect(updated_resource).not_to have_labels
          expect(updated_resource).not_to have_annotations
        end
      end
    end
  end
end
