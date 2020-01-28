require 'spec_helper'
require 'actions/service_instance_update'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUpdate do
    describe '#update' do
      let(:body) do
        {
          metadata: {
            labels: {
              freaky: 'wednesday',
            },
            annotations: {
              tokyo: 'grapes'
            },
          },
        }
      end
      let(:service_instance) { ServiceInstance.make }
      let(:message) { ServiceInstanceUpdateMessage.new(body) }

      context 'When there are no keys in metadata already' do
        it 'adds the new keys' do
          expect(message).to be_valid
          ServiceInstanceUpdate.update(service_instance, message)

          service_instance.reload
          expect(service_instance.labels.map { |label| { key: label.key_name, value: label.value } }).to match_array([{ key: 'freaky', value: 'wednesday' }])
          expect(service_instance.annotations.map { |a| { key: a.key, value: a.value } }).
            to match_array([{ key: 'tokyo', value: 'grapes' }])
        end
      end

      context 'When there are already keys in metadata' do
        let(:body) do
          {
            metadata: {
              labels: {
                freaky: 'wednesday',
                to_delete_no_prefix: nil,
                'pre.fix/to_delete': nil
              },
              annotations: {
                tokyo: 'grapes',
                to_delete_no_prefix: nil,
                'pre.fix/to_delete': nil

              },
            },
          }
        end

        let(:message) { ServiceInstanceUpdateMessage.new(body) }

        before do
          annotation = VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value')
          annotation_no_prefix = VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_name: 'to_delete_no_prefix', value: 'value')
          label = VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value')
          label_no_prefix = VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'to_delete_no_prefix', value: 'value')
          service_instance.annotation_ids = [annotation.id, annotation_no_prefix.id]
          service_instance.label_ids = [label.id, label_no_prefix.id]
        end

        it 'deletes the keys when values are nil' do
          expect(message).to be_valid
          ServiceInstanceUpdate.update(service_instance, message)
          service_instance.reload
          expect(service_instance).to contain_metadata({
            metadata: {
              labels: {
                freaky: 'wednesday',
              },
              annotations: {
                tokyo: 'grapes',
              },
            },
          })
        end
      end
    end
  end
end
