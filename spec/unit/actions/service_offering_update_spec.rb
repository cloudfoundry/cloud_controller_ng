require 'spec_helper'
require 'actions/service_offering_update'

module VCAP::CloudController
  RSpec.describe ServiceOfferingUpdate do
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
      let(:service_offering) { Service.make }
      let(:message) { ServiceOfferingUpdateMessage.new(update_request_body) }

      context 'when the service offering has no metadata' do
        context 'and no metadata is specified' do
          let(:update_request_body) { {} }

          it 'adds no metadata' do
            expect(message).to be_valid
            updated_service_offering = ServiceOfferingUpdate.update(service_offering, message)

            service_offering.reload

            expect(service_offering).to eq(updated_service_offering)
            expect(updated_service_offering.labels).to be_empty
            expect(updated_service_offering.annotations).to be_empty
          end
        end

        it 'adds metadata to a service_offering' do
          expect(message).to be_valid
          updated_service_offering = ServiceOfferingUpdate.update(service_offering, message)
          expect(updated_service_offering).to contain_metadata(new_metadata)

          service_offering.reload
          expect(service_offering).to eq(updated_service_offering)
        end
      end

      context 'when the service offering has existing metadata' do
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
          VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: service_offering.guid, key_name: 'freaky', value: 'tuesday')
          VCAP::CloudController::ServiceOfferingAnnotationModel.make(resource_guid: service_offering.guid, key: 'tokyo', value: 'apples')
        end

        context 'and no metadata is specified' do
          let(:update_request_body) { {} }

          it 'does not change the existing values' do
            expect(message).to be_valid
            updated_service_offering = ServiceOfferingUpdate.update(service_offering, message)

            service_offering.reload

            expect(service_offering).to eq(updated_service_offering)
            expect(updated_service_offering).to contain_metadata(old_metadata)
          end
        end

        it 'can add new values' do
          new_metadata = old_metadata.tap do |m|
            m[:metadata][:labels][:another_label] = 'new-label'
            m[:metadata][:labels][:another_annotation] = 'new-annotation'
          end
          message = ServiceOfferingUpdateMessage.new(new_metadata)

          expect(message).to be_valid
          updated_service_offering = ServiceOfferingUpdate.update(service_offering, message)
          expect(updated_service_offering).to contain_metadata(new_metadata)
        end

        it 'can update existing values' do
          expect(message).to be_valid
          updated_service_offering = ServiceOfferingUpdate.update(service_offering, message)
          expect(updated_service_offering).to contain_metadata(new_metadata)
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
          new_message = ServiceOfferingUpdateMessage.new(new_body)

          expect(new_message).to be_valid

          updated_service_offering = ServiceOfferingUpdate.update(service_offering, new_message)
          expect(updated_service_offering.labels).to be_empty
          expect(updated_service_offering.annotations).to be_empty
        end
      end
    end
  end
end
