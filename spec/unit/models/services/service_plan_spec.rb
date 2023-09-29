require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServicePlan, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :service }
      it { is_expected.to have_associated :service_instances, class: ManagedServiceInstance }
      it { is_expected.to have_associated :service_plan_visibilities }
      it { is_expected.to have_associated :labels, class: ServicePlanLabelModel }
      it { is_expected.to have_associated :annotations, class: ServicePlanAnnotationModel }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name, message: 'is required' }
      it { is_expected.to validate_presence :free, message: 'is required' }
      it { is_expected.to validate_presence :description, message: 'is required' }
      it { is_expected.to validate_presence :service, message: 'is required' }
      it { is_expected.to strip_whitespace :name }

      context 'when the unique_id is not unique across different services' do
        let(:existing_service_plan) { ServicePlan.make }
        let(:service_plan) { ServicePlan.make(unique_id: existing_service_plan.unique_id, service: Service.make) }

        it 'is valid' do
          expect(service_plan).to be_valid
        end
      end

      context 'for plans belonging to private brokers' do
        it 'does not allow the plan to be public' do
          space = Space.make
          private_broker = ServiceBroker.make(space:)
          service = Service.make service_broker: private_broker

          expect do
            ServicePlan.make service: service, public: true
          end.to raise_error Sequel::ValidationFailed, 'public may not be true for plans belonging to private service brokers'
        end
      end
    end

    describe 'Serialization' do
      it 'exports these attributes' do
        expect(subject).to export_attributes :name,
                                             :free,
                                             :description,
                                             :service_guid,
                                             :extra,
                                             :unique_id,
                                             :public,
                                             :bindable,
                                             :plan_updateable,
                                             :maximum_polling_duration,
                                             :maintenance_info,
                                             :active,
                                             :create_instance_schema,
                                             :update_instance_schema,
                                             :create_binding_schema
      end

      it 'imports these attributes' do
        expect(subject).to import_attributes :name,
                                             :free,
                                             :description,
                                             :service_guid,
                                             :extra,
                                             :unique_id,
                                             :public,
                                             :bindable,
                                             :plan_updateable,
                                             :maximum_polling_duration,
                                             :maintenance_info,
                                             :create_instance_schema,
                                             :update_instance_schema,
                                             :create_binding_schema
      end
    end

    describe '#save' do
      context 'before_filters' do
        it 'defaults public to true if a value is not supplied' do
          service = Service.make

          expect(ServicePlan.make(service: service, public: false).public).to be(false)
          expect(ServicePlan.make(service: service, public: true).public).to be(true)
          expect(ServicePlan.make(service:).public).to be(true)
        end

        it 'defaults to false if a value is not supplied but a private broker is' do
          space = Space.make
          private_broker = ServiceBroker.make space_id: space.id, space_guid: space.guid
          service = Service.make service_broker: private_broker

          expect(ServicePlan.make(service: service, public: false).public).to be(false)
          expect(ServicePlan.make(service:).public).to be(false)
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
          let(:service) { Service.make(label: 'my-service') }

          before { ServicePlan.make(name: 'dumbo', service_id: service.id) }

          it 'throws a useful error' do
            expect { ServicePlan.make(name: 'dumbo', service_id: service.id) }.
              to raise_exception('Plan names must be unique within a service. Service my-service already has a plan named dumbo')
          end
        end
      end

      context 'on update' do
        let(:plan) { ServicePlan.make }

        context 'when the unique_id is unset' do
          before { plan.unique_id = nil }

          it 'does not generate a unique_id' do
            expect do
              plan.save
            rescue StandardError
              nil
            end.not_to change(plan, :unique_id)
          end

          it 'raises a validation error' do
            expect do
              plan.save
            end.to raise_error(Sequel::ValidationFailed)
          end
        end
      end
    end

    describe '#destroy' do
      let(:service_plan) { ServicePlan.make }

      it 'destroys associated dependencies' do
        service_plan_visibility = ServicePlanVisibility.make(service_plan:)
        service_plan_label = ServicePlanLabelModel.make(resource_guid: service_plan.guid, key_name: 'flavor', value: 'pear')
        service_plan_annotation = ServicePlanAnnotationModel.make(resource_guid: service_plan.guid, key_name: 'colour', value: 'purple')

        service_plan.destroy

        expect(ServicePlanVisibility.where(id: service_plan_visibility.id)).to be_empty
        expect(ServiceOfferingLabelModel.where(id: service_plan_label.id)).to be_empty
        expect(ServicePlanAnnotationModel.where(id: service_plan_annotation.id)).to be_empty
      end

      it 'cannot be destroyed if associated service_instances exist' do
        service_plan = ServicePlan.make
        ManagedServiceInstance.make(service_plan:)
        expect do
          service_plan.destroy
        end.to raise_error Sequel::DatabaseError, /foreign key/
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
        expect(ServicePlan.plan_ids_from_private_brokers(user).select_map(:service_plans__id)).to(contain_exactly(service_plan_1.id, service_plan_2.id))
      end

      it "doesn't return plans for private services in spaces the user doesn't have roles in" do
        broker = ServiceBroker.make
        service = Service.make(service_broker: broker)
        plan = ServicePlan.make(service: service, public: false)

        expect(ServicePlan.plan_ids_from_private_brokers(user).select_map(:service_plans__id)).not_to include plan
      end
    end

    describe '.plan_ids_for_visible_service_instances' do
      context 'when the service plans have service instances associated with them' do
        let(:organization) { Organization.make }
        let(:space) { Space.make(organization:) }
        let(:other_space) { Space.make(organization:) }
        let(:user) { User.make }
        let(:broker) { ServiceBroker.make }
        let(:service) { Service.make(service_broker: broker) }
        let(:service_plan) { ServicePlan.make(service: service, public: true, active: true) }
        let(:non_public_plan) { ServicePlan.make(service: service, public: false, active: true) }
        let(:inactive_plan) { ServicePlan.make(service: service, public: true, active: false) }
        let(:other_plan) { ServicePlan.make(service: service, public: true, active: true) }
        let!(:service_instance) { ManagedServiceInstance.make(service_plan:, space:) }
        let!(:service_instance2) { ManagedServiceInstance.make(service_plan: non_public_plan, space: space) }
        let!(:service_instance3) { ManagedServiceInstance.make(service_plan: inactive_plan, space: space) }
        let!(:user_provided_service_instance) { UserProvidedServiceInstance.make(space:) }
        let!(:other_service_instance) { ManagedServiceInstance.make(service_plan: other_plan, space: other_space) }

        before do
          organization.add_user user
          space.add_developer user
        end

        context 'when the service instances are in spaces that the user has a role in' do
          it 'returns all plans regardless of active or public' do
            expect(ServicePlan.plan_ids_for_visible_service_instances(user).select_map(:service_plans__id)).
              to contain_exactly(service_plan.id, non_public_plan.id, inactive_plan.id)
          end
        end

        context 'when the service instances are in spaces that the user does NOT have a role in' do
          it 'does not return service plans associated with that service instance' do
            expect(ServicePlan.plan_ids_for_visible_service_instances(user).select_map(:service_plans__id)).not_to include(other_plan.id)
          end
        end
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

    describe '.space_visible' do
      it 'returns plans that are visible to the space' do
        hidden_private_plan = ServicePlan.make(public: false)
        visible_public_plan = ServicePlan.make(public: true)
        visible_private_plan = ServicePlan.make(public: false)
        inactive_public_plan = ServicePlan.make(public: true, active: false)

        organization = Organization.make
        space = Space.make(organization:)
        ServicePlanVisibility.make(organization: organization, service_plan: visible_private_plan)

        space_scoped_broker1 = ServiceBroker.make(space:)
        space_scoped_broker1_service = Service.make(service_broker: space_scoped_broker1)
        space_scoped_broker1_plan = ServicePlan.make(service: space_scoped_broker1_service)
        space_scoped_broker1_plan_inactive = ServicePlan.make(service: space_scoped_broker1_service, active: false)

        space_scoped_broker2 = ServiceBroker.make(space: Space.make)
        space_scoped_broker2_service = Service.make(service_broker: space_scoped_broker2)
        space_scoped_broker2_plan = ServicePlan.make(service: space_scoped_broker2_service)

        visible = ServicePlan.space_visible(space).all
        expect(visible).to include(visible_public_plan)
        expect(visible).to include(visible_private_plan)
        expect(visible).not_to include(hidden_private_plan)
        expect(visible).not_to include(inactive_public_plan)

        expect(visible).to include(space_scoped_broker1_plan)
        expect(visible).not_to include(space_scoped_broker1_plan_inactive)
        expect(visible).not_to include(space_scoped_broker2_plan)
      end
    end

    describe '#visible_in_space?' do
      it 'returns true when included in .space_visible set' do
        visible_private_plan = ServicePlan.make(public: false)

        organization = Organization.make
        space = Space.make(organization:)
        ServicePlanVisibility.make(organization: organization, service_plan: visible_private_plan)

        visible = ServicePlan.space_visible(space).all
        expect(visible).to include(visible_private_plan)
        expect(visible_private_plan.visible_in_space?(space)).to be true
      end

      it 'returns false when not included in .space_visible set' do
        hidden_private_plan = ServicePlan.make(public: false)
        organization = Organization.make
        space = Space.make(organization:)

        visible = ServicePlan.space_visible(space).all
        expect(visible).not_to include(hidden_private_plan)
        expect(hidden_private_plan.visible_in_space?(space)).to be false
      end
    end

    describe '#bindable?' do
      let(:service_plan) { ServicePlan.make(service: service, bindable: plan_bindable) }

      context 'when the plan does not specify if it is bindable' do
        let(:plan_bindable) { nil }

        context 'and the service is bindable' do
          let(:service) { Service.make(bindable: true) }

          specify { expect(service_plan).to be_bindable }
        end

        context 'and the service is unbindable' do
          let(:service) { Service.make(bindable: false) }

          specify { expect(service_plan).not_to be_bindable }
        end
      end

      context 'when the plan is explicitly set to not be bindable' do
        let(:plan_bindable) { false }

        context 'and the service is bindable' do
          let(:service) { Service.make(bindable: true) }

          specify { expect(service_plan).not_to be_bindable }
        end

        context 'and the service is unbindable' do
          let(:service) { Service.make(bindable: false) }

          specify { expect(service_plan).not_to be_bindable }
        end
      end

      context 'when the plan is explicitly set to be bindable' do
        let(:plan_bindable) { true }

        context 'and the service is bindable' do
          let(:service) { Service.make(bindable: true) }

          specify { expect(service_plan).to be_bindable }
        end

        context 'and the service is unbindable' do
          let(:service) { Service.make(bindable: false) }

          specify { expect(service_plan).to be_bindable }
        end
      end
    end

    describe '#plan_updateable?' do
      let(:service_plan) { ServicePlan.make(service:, plan_updateable:) }

      context 'when the plan does not specify if it is updateable' do
        let(:plan_updateable) { nil }

        context 'and the service is plan_updateable' do
          let(:service) { Service.make(plan_updateable: true) }

          specify { expect(service_plan).to be_plan_updateable }
        end

        context 'and the service is not plan_updateable' do
          let(:service) { Service.make(plan_updateable: false) }

          specify { expect(service_plan).not_to be_plan_updateable }
        end
      end

      context 'when the plan is explicitly set to not be updateable' do
        let(:plan_updateable) { false }

        context 'and the service is plan_updateable' do
          let(:service) { Service.make(plan_updateable: true) }

          specify { expect(service_plan).not_to be_plan_updateable }
        end

        context 'and the service is not plan_updateable' do
          let(:service) { Service.make(plan_updateable: false) }

          specify { expect(service_plan).not_to be_plan_updateable }
        end
      end

      context 'when the plan is explicitly set to be updateable' do
        let(:plan_updateable) { true }

        context 'and the service is updateable' do
          let(:service) { Service.make(plan_updateable: true) }

          specify { expect(service_plan).to be_plan_updateable }
        end

        context 'and the service is not updateable' do
          let(:service) { Service.make(plan_updateable: false) }

          specify { expect(service_plan).to be_plan_updateable }
        end
      end

      context 'when updateable is nil' do
        let(:plan_updateable) { nil }

        context 'and the service updateable is also nil' do
          let(:service) { Service.make(plan_updateable: nil) }

          specify { expect(service_plan.plan_updateable?).to be(false) }
        end
      end
    end

    describe '#broker_space_scoped?' do
      it 'returns true if the plan belongs to a service that belongs to a private broker' do
        space = Space.make
        broker = ServiceBroker.make(space:)
        service = Service.make service_broker: broker
        plan = ServicePlan.make(service:)

        expect(plan).to be_broker_space_scoped
      end

      it 'returns false if the plan belongs to a service that belongs to a public broker' do
        plan = ServicePlan.make

        expect(plan).not_to be_broker_space_scoped
      end
    end

    describe '.visibility_type' do
      it 'returns "public" for public plans' do
        plan = ServicePlan.make(public: true)

        expect(plan.visibility_type).to eq('public')
      end

      it 'returns "admin" for private plans' do
        plan = ServicePlan.make(public: false)

        expect(plan.visibility_type).to eq('admin')
      end

      it 'returns "space" for plans from space-scoped brokers' do
        plan = ServicePlan.make(service: Service.make(service_broker: ServiceBroker.make(space: Space.make)))

        expect(plan.visibility_type).to eq('space')
      end

      it 'returns "organization" for org restricted plans' do
        plan = ServicePlanVisibility.make(
          service_plan: ServicePlan.make(public: false),
          organization: Organization.make
        ).service_plan

        expect(plan.visibility_type).to eq('organization')
      end
    end
  end
end
