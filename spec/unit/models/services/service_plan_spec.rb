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

      context 'for plans belonging to private brokers' do
        it 'does not allow the plan to be public' do
          space = Space.make
          private_broker = ServiceBroker.make space: space
          service = Service.make service_broker: private_broker

          expect {
            ServicePlan.make service: service, public: true
          }.to raise_error Sequel::ValidationFailed, 'public may not be true for plans belonging to private service brokers'
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :free, :description, :service_guid, :extra, :unique_id, :public, :active }
      it { is_expected.to import_attributes :name, :free, :description, :service_guid, :extra, :unique_id, :public }
    end

    describe '#save' do
      context 'before_filters' do
        it 'defaults public to true if a value is not supplied' do
          service = Service.make

          expect(ServicePlan.make(service: service, public: false).public).to be(false)
          expect(ServicePlan.make(service: service, public: true).public).to be(true)
          expect(ServicePlan.make(service: service).public).to be(true)
        end

        it 'defaults to false if a value is not supplied but a private broker is' do
          space = Space.make
          private_broker = ServiceBroker.make space_id: space.id, space_guid: space.guid
          service = Service.make service_broker: private_broker

          expect(ServicePlan.make(service: service, public: false).public).to be(false)
          expect(ServicePlan.make(service: service).public).to be(false)
        end
      end

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

    describe '.plan_ids_from_private_brokers' do
      let(:organization) { Organization.make }
      let(:space_1) { Space.make(organization: organization, id: Space.count + 9998) }
      let(:space_2) { Space.make(organization: organization, id: Space.count + 9999) }
      let(:user) { User.make }
      let(:broker_1) { ServiceBroker.make(space: space_1) }
      let(:broker_2) { ServiceBroker.make(space: space_2) }
      let(:service_1) { Service.make(service_broker: broker_1) }
      let(:service_2) { Service.make(service_broker: broker_2) }
      let!(:service_plan_1) { ServicePlan.make(service: service_1, public: false) }
      let!(:service_plan_2) { ServicePlan.make(service: service_2, public: false) }

      before do
        organization.add_user user
        space_1.add_developer user
        space_2.add_manager user
      end

      it 'returns plans from private service brokers in all the spaces the user has roles in' do
        expect(ServicePlan.plan_ids_from_private_brokers(user)).to(match_array([service_plan_1.id, service_plan_2.id]))
      end

      it "doesn't return plans for private services in spaces the user doesn't have roles in" do
        broker = ServiceBroker.make
        service = Service.make(service_broker: broker)
        plan = ServicePlan.make(service: service, public: false)

        expect(ServicePlan.plan_ids_from_private_brokers(user)).not_to include plan
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

    describe '#broker_private?' do
      it 'returns true if the plan belongs to a service that belongs to a private broker' do
        space = Space.make
        broker = ServiceBroker.make space: space
        service = Service.make service_broker: broker
        plan = ServicePlan.make service: service

        expect(plan.broker_private?).to be_truthy
      end

      it 'returns false if the plan belongs to a service that belongs to a public broker' do
        plan = ServicePlan.make

        expect(plan.broker_private?).to be_falsey
      end
    end
  end
end
