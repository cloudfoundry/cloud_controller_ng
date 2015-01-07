require 'spec_helper'

module VCAP::CloudController
  describe ServicePlan, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :service }
      it { is_expected.to have_associated :service_instances, class: ManagedServiceInstance }
      it { is_expected.to have_associated :service_plan_visibilities }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name, message: 'is required' }
      it { is_expected.to validate_presence :free, message: 'is required' }
      it { is_expected.to validate_presence :description, message: 'is required' }
      it { is_expected.to validate_presence :service, message: 'is required' }
      it { is_expected.to strip_whitespace :name }

      context 'when the unique_id is not unique' do
        let(:existing_service_plan) { ServicePlan.make }
        let(:service_plan) { ServicePlan.make_unsaved(unique_id: existing_service_plan.unique_id, service: Service.make) }

        it 'is not valid' do
          expect(service_plan).not_to be_valid
        end

        it 'raises an error on save' do
          expect { service_plan.save }.
            to raise_error(Sequel::ValidationFailed, 'Plan ids must be unique')
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :free, :description, :service_guid, :extra, :unique_id, :public, :active }
      it { is_expected.to import_attributes :name, :free, :description, :service_guid, :extra, :unique_id, :public }
    end

    describe '#save' do
      context 'on create' do
        context 'when no unique_id is set' do
          let(:attrs) { { unique_id: nil } }

          it 'generates guid for the unique_id' do
            plan = ServicePlan.make(attrs)
            expect(plan.unique_id).to be_a_guid
          end
        end

        context 'when a unique_id is set' do
          let(:attrs) { { unique_id: Sham.guid } }

          it 'persists the given unique_id' do
            plan = ServicePlan.make(attrs)
            expect(plan.unique_id).to eq(attrs[:unique_id])
          end
        end

        context 'when a plan with the same name has already been added for this service' do
          let(:attrs1) { { name: 'dumbo', service_id: service.id } }
          let(:attrs2) { { name: 'dumbo', service_id: service.id } }
          let(:service) { Service.make({}) }

          before { ServicePlan.make(attrs1) }

          it 'throws a useful error' do
            expect { ServicePlan.make(attrs2) }.to raise_exception('Plan names must be unique within a service')
          end
        end
      end

      context 'on update' do
        let(:plan) { ServicePlan.make }

        context 'when the unique_id is unset' do
          before { plan.unique_id = nil }

          it 'does not generate a unique_id' do
            expect {
              plan.save rescue nil
            }.to_not change(plan, :unique_id)
          end

          it 'raises a validation error' do
            expect {
              plan.save
            }.to raise_error(Sequel::ValidationFailed)
          end
        end
      end
    end

    describe '#destroy' do
      let(:service_plan) { ServicePlan.make }

      it 'destroys all service plan visibilities' do
        service_plan_visibility = ServicePlanVisibility.make(service_plan: service_plan)
        expect { service_plan.destroy }.to change {
          ServicePlanVisibility.where(id: service_plan_visibility.id).any?
        }.to(false)
      end

      it 'cannot be destroyed if associated service_instances exist' do
        service_plan = ServicePlan.make
        ManagedServiceInstance.make(service_plan: service_plan)
        expect {
          service_plan.destroy
        }.to raise_error Sequel::DatabaseError, /foreign key/
      end
    end

    describe '.organization_visible' do
      it 'returns plans that are visible to the organization' do
        hidden_private_plan = ServicePlan.make(public: false)
        visible_public_plan = ServicePlan.make(public: true)
        visible_private_plan = ServicePlan.make(public: false)
        inactive_public_plan = ServicePlan.make(public: true, active: false)

        organization = Organization.make
        ServicePlanVisibility.make(organization: organization, service_plan: visible_private_plan)

        visible = ServicePlan.organization_visible(organization).all
        expect(visible).to include(visible_public_plan)
        expect(visible).to include(visible_private_plan)
        expect(visible).not_to include(hidden_private_plan)
        expect(visible).not_to include(inactive_public_plan)
      end
    end

    describe '#bindable?' do
      let(:service_plan) { ServicePlan.make(service: service) }

      context 'when the service is bindable' do
        let(:service) { Service.make(bindable: true) }
        specify { expect(service_plan).to be_bindable }
      end

      context 'when the service is unbindable' do
        let(:service) { Service.make(bindable: false) }
        specify { expect(service_plan).not_to be_bindable }
      end
    end
  end
end
