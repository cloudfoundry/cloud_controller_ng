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
            expect(updated_resource.labels).to be_empty
            expect(updated_resource.annotations).to be_empty
          end
        end

        it 'adds metadata to a resource' do
          expect(message).to be_valid
          updated_resource = TransactionalMetadataUpdate.update(resource, message)
          expect(updated_resource).to contain_metadata(new_metadata)

          resource.reload
          expect(resource).to eq(updated_resource)
        end
      end

      context 'when the resource has existing metadata' do
        let(:old_metadata) {
          {
            metadata: {
              labels: {
                freaky: 'tuesday'
              },
              annotations: {
                tokyo: 'apples'
              }
            }
          }
        }

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
            expect(updated_resource).to contain_metadata(old_metadata)
          end
        end

        it 'can add new values' do
          new_metadata = old_metadata.tap do |m|
            m[:metadata][:labels][:another_label] = 'new-label'
            m[:metadata][:labels][:another_annotation] = 'new-annotation'
          end
          message = MetadataUpdateMessage.new(new_metadata)

          expect(message).to be_valid
          updated_resource = TransactionalMetadataUpdate.update(resource, message)
          expect(updated_resource).to contain_metadata(new_metadata)
        end

        it 'can update existing values' do
          expect(message).to be_valid
          updated_resource = TransactionalMetadataUpdate.update(resource, message)
          expect(updated_resource).to contain_metadata(new_metadata)
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
          expect(updated_resource.labels).to be_empty
          expect(updated_resource.annotations).to be_empty
        end
      end
    end
  end
end
