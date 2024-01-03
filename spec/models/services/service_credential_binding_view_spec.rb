require 'spec_helper'

module VCAP::CloudController
  module ServiceCredentialBinding
    RSpec.describe View do
      describe 'Associations' do
        describe 'service_instance_sti_eager_load' do
          it 'eager loads successfully' do
            instance1 = UserProvidedServiceInstance.make
            instance2 = ManagedServiceInstance.make
            binding = ServiceBinding.make(service_instance: instance1)
            key = ServiceKey.make(service_instance: instance2)
            eager_loaded_service_credential_bindings = nil
            expect do
              eager_loaded_service_credential_bindings = View.eager(:service_instance_sti_eager_load).all.to_a
            end.to have_queried_db_times(/select \* from .service_instances. where/i, 1)

            expect do
              eager_loaded_service_credential_bindings.each(&:service_instance)
            end.to have_queried_db_times(//i, 0)

            found_binding = eager_loaded_service_credential_bindings.detect { |b| b.guid == binding.guid }
            found_key = eager_loaded_service_credential_bindings.detect { |k| k.guid == key.guid }
            expect(found_binding.service_instance).to eq(instance1)
            expect(found_key.service_instance).to eq(instance2)
          end
        end

        describe 'labels_sti_eager_load' do
          it 'eager loads successfully' do
            binding = ServiceBinding.make
            lb1 = ServiceBindingLabelModel.make(service_binding: binding, key_name: 'test1', value: 'bommel')
            lb2 = ServiceBindingLabelModel.make(service_binding: binding, key_name: 'test2', value: 'bommel')
            key = ServiceKey.make
            lk1 = ServiceKeyLabelModel.make(service_key: key, key_name: 'test1', value: 'bommel')
            lk2 = ServiceKeyLabelModel.make(service_key: key, key_name: 'test2', value: 'bommel')

            eager_loaded_service_credential_bindings = nil
            expect do
              eager_loaded_service_credential_bindings = View.eager(:labels_sti_eager_load).all.to_a
            end.to have_queried_db_times(/service_key_labels|service_binding_labels/i, 2)

            expect do
              eager_loaded_service_credential_bindings.each(&:labels)
            end.to have_queried_db_times(//i, 0)

            found_binding = eager_loaded_service_credential_bindings.detect { |b| b.guid == binding.guid }
            found_key = eager_loaded_service_credential_bindings.detect { |k| k.guid == key.guid }
            expect(found_binding.labels).to contain_exactly(lb1, lb2)
            expect(found_key.labels).to contain_exactly(lk1, lk2)
          end
        end

        describe 'annotations_sti_eager_load' do
          it 'eager loads successfully' do
            binding = ServiceBinding.make
            lb1 = ServiceBindingAnnotationModel.make(service_binding: binding, key_name: 'test1', value: 'bommel')
            lb2 = ServiceBindingAnnotationModel.make(service_binding: binding, key_name: 'test2', value: 'bommel')
            key = ServiceKey.make
            lk1 = ServiceKeyAnnotationModel.make(service_key: key, key_name: 'test1', value: 'bommel')
            lk2 = ServiceKeyAnnotationModel.make(service_key: key, key_name: 'test2', value: 'bommel')

            eager_loaded_service_credential_bindings = nil
            expect do
              eager_loaded_service_credential_bindings = View.eager(:annotations_sti_eager_load).all.to_a
            end.to have_queried_db_times(/service_key_annotations|service_binding_annotations/i, 2)

            expect do
              eager_loaded_service_credential_bindings.each(&:annotations)
            end.to have_queried_db_times(//i, 0)

            found_binding = eager_loaded_service_credential_bindings.detect { |b| b.guid == binding.guid }
            found_key = eager_loaded_service_credential_bindings.detect { |k| k.guid == key.guid }
            expect(found_binding.annotations).to contain_exactly(lb1, lb2)
            expect(found_key.annotations).to contain_exactly(lk1, lk2)
          end
        end

        describe 'operation_sti_eager_load' do
          it 'eager loads successfully' do
            binding = ServiceBinding.make.save
            bo = ServiceBindingOperation.make(service_binding_id: binding.id)
            key = ServiceKey.make
            ko = ServiceKeyOperation.make(service_key_id: key.id)

            eager_loaded_service_credential_bindings = nil
            expect do
              eager_loaded_service_credential_bindings = View.eager(:operation_sti_eager_load).all.to_a
            end.to have_queried_db_times(/service_key_operation|service_binding_operation/i, 2)

            expect do
              eager_loaded_service_credential_bindings.each(&:last_operation)
            end.to have_queried_db_times(//i, 0)

            found_binding = eager_loaded_service_credential_bindings.detect { |b| b.guid == binding.guid }
            found_key = eager_loaded_service_credential_bindings.detect { |k| k.guid == key.guid }
            expect(found_binding.last_operation).to eq(bo)
            expect(found_key.last_operation).to eq(ko)
          end
        end
      end
    end
  end
end
