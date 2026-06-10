require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Service, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :service_broker }
      it { is_expected.to have_associated :service_plans }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :label, message: 'Service name is required' }
      it { is_expected.to validate_presence :description, message: 'is required' }
      it { is_expected.to validate_presence :bindable, message: 'is required' }
      it { is_expected.to strip_whitespace :label }

      describe 'urls' do
        it 'validates format of info_url' do
          service = build(:service, info_url: 'bogus_url', service_broker: nil)
          expect(service).not_to be_valid
          expect(service.errors.on(:info_url)).to include 'must be a valid url'
        end
      end

      context 'when the tags are longer than 2048 characters' do
        it 'raises an error on save' do
          super_long_tag = 'a' * 2049
          expect do
            create(:service, label: 'super-long-service', tags: [super_long_tag])
          end.to raise_error('Service tags for service super-long-service must be 2048 characters or less.')
        end
      end
    end

    describe 'Serialization' do
      it {
        expect(subject).to export_attributes :label, :provider, :url, :description, :long_description, :version, :info_url, :active, :bindable,
                                             :unique_id, :extra, :tags, :requires, :documentation_url, :service_broker_guid, :plan_updateable, :bindings_retrievable,
                                             :instances_retrievable, :allow_context_updates
      }

      it {
        expect(subject).to import_attributes :label, :description, :long_description, :info_url,
                                             :active, :bindable, :unique_id, :extra, :tags, :requires, :documentation_url, :plan_updateable, :bindings_retrievable,
                                             :instances_retrievable, :allow_context_updates
      }
    end

    describe '#destroy' do
      let(:service_offering) { create(:service) }

      it 'deletes associated resources' do
        label = create(:service_offering_label_model, resource_guid: service_offering.guid, key_name: 'foo', value: 'bar')
        annotation = create(:service_offering_annotation_model, resource_guid: service_offering.guid, key_name: 'alpha', value: 'beta')

        service_offering.destroy

        expect(ServiceOfferingLabelModel.where(id: label.id)).to be_empty
        expect(ServiceOfferingAnnotationModel.where(id: annotation.id)).to be_empty
      end
    end

    describe '#user_visibility_filter' do
      let(:private_service) { create(:service) }
      let(:public_service) { create(:service) }
      let(:nonadmin_org) { create(:organization) }
      let(:admin_user) { create(:user) }
      let(:nonadmin_user) { create(:user) }
      let!(:private_plan) { create(:service_plan, service: private_service, public: false) }

      before do
        create(:service_plan, service: public_service, public: true)
        create(:service_plan, service: public_service, public: false)
        VCAP::CloudController::SecurityContext.set(admin_user, { 'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] })
        nonadmin_user.add_organization nonadmin_org
        VCAP::CloudController::SecurityContext.clear
      end

      def records(user)
        Service.user_visible(user, user == admin_user).all
      end

      it 'returns all services for admins' do
        expect(records(admin_user)).to include(private_service, public_service)
      end

      it 'only returns public services for nonadmins' do
        expect(records(nonadmin_user)).to include(public_service)
        expect(records(nonadmin_user)).not_to include(private_service)
      end

      it 'returns private services if a user can see a plan inside them' do
        ServicePlanVisibility.create(
          organization: nonadmin_org,
          service_plan: private_plan
        )
        expect(records(nonadmin_user)).to include(private_service, public_service)
      end

      it 'returns public services for unauthenticated users' do
        records = Service.user_visible(nil).all
        expect(records).to eq [public_service]
      end

      describe 'services from private brokers' do
        it 'does not return the services to users with no roles in the space' do
          space = create(:space)
          space_developer = create(:user)

          space.organization.add_user space_developer

          private_broker = create(:service_broker, space:)
          service = create(:service, service_broker: private_broker, active: true)
          create(:service_plan, service: service, active: true, public: false)

          records = Service.user_visible(space_developer).all
          expect(records.map(&:guid)).not_to include service.guid
        end

        it "returns services from private brokers to space developers in that private broker's space" do
          space = create(:space)
          space_developer = create(:user)

          space.organization.add_user space_developer

          space.add_developer space_developer

          private_broker = create(:service_broker, space:)
          service = create(:service, service_broker: private_broker, active: true)
          create(:service_plan, service: service, active: true, public: false)

          records = Service.user_visible(space_developer).all
          expect(records.map(&:guid)).to include service.guid
        end

        it "returns services from private brokers to space auditors in that private broker's space" do
          space = create(:space)
          space_auditor = create(:user)

          space.organization.add_user space_auditor

          space.add_auditor space_auditor

          private_broker = create(:service_broker, space:)
          service = create(:service, service_broker: private_broker, active: true)
          create(:service_plan, service: service, active: true, public: false)
          records = Service.user_visible(space_auditor).all
          expect(records.map(&:guid)).to include service.guid
        end

        it "returns services from private brokers to space managers in that private broker's space" do
          space = create(:space)
          space_manager = create(:user)

          space.organization.add_user space_manager

          space.add_manager space_manager

          private_broker = create(:service_broker, space:)
          service = create(:service, service_broker: private_broker, active: true)
          create(:service_plan, service: service, active: true, public: false)
          records = Service.user_visible(space_manager).all
          expect(records).to include service
        end
      end
    end

    describe '#tags' do
      it 'returns the provided service tags' do
        service = create(:service, tags: %w[a b c])
        expect(service.tags).to match_array(%w[a b c])
      end

      context 'null tags in the database' do
        it 'returns an empty array' do
          service = create(:service, tags: nil)
          expect(service.tags).to eq []
        end
      end
    end

    describe '#requires' do
      context 'null requires in the database' do
        it 'returns an empty array' do
          service = create(:service, requires: nil)
          expect(service.requires).to eq []
        end
      end
    end

    describe '#documentation_url' do
      context 'with a URL in the database' do
        it 'returns the appropriate URL' do
          sham_url = Sham.url
          service = create(:service, documentation_url: sham_url)
          expect(service.documentation_url).to eq sham_url
        end
      end
    end

    describe '#long_description' do
      context 'with a long description in the database' do
        it 'return the appropriate long description' do
          sham_long_description = Sham.long_description
          service = create(:service, long_description: sham_long_description)
          expect(service.long_description).to eq sham_long_description
        end
      end
    end

    describe '#purge' do
      let!(:event_repository) { double(Repositories::ServiceUsageEventRepository) }
      let!(:service_plan) { create(:service_plan, service: service, public: false) }
      let!(:service_plan_visibility) { create(:service_plan_visibility, service_plan:) }
      let!(:service_instance) { create(:managed_service_instance, service_plan:) }
      let!(:service_binding) { create(:service_binding, service_instance:) }

      let!(:service_plan_2) { create(:service_plan, service: service, public: false) }
      let!(:service_plan_visibility_2) { create(:service_plan_visibility, service_plan: service_plan_2) }
      let!(:service_instance_2) { create(:managed_service_instance, service_plan: service_plan_2) }
      let!(:service_binding_2) { create(:service_binding, service_instance: service_instance_2) }
      let!(:service) { create(:service) }

      before do
        allow(Repositories::ServiceUsageEventRepository).to receive(:new).and_return(event_repository)
        allow(event_repository).to receive(:deleted_event_from_service_instance)
        allow(event_repository).to receive(:record_service_instance_event)
        allow(event_repository).to receive(:user_audit_info).and_return(instance_double(UserAuditInfo).as_null_object)
      end

      it 'destroys all models that depend on it' do
        service.purge(event_repository)

        expect(Service.find(guid: service.guid)).to be_nil
        expect(ServicePlan.first(guid: service_plan.guid)).to be_nil
        expect(ServicePlan.first(guid: service_plan_2.guid)).to be_nil
        expect(ServicePlanVisibility.first(guid: service_plan_visibility.guid)).to be_nil
        expect(ServicePlanVisibility.first(guid: service_plan_visibility_2.guid)).to be_nil
        expect(ServiceInstance.first(guid: service_instance.guid)).to be_nil
        expect(ServiceInstance.first(guid: service_instance_2.guid)).to be_nil
        expect(ServiceBinding.first(guid: service_binding.guid)).to be_nil
        expect(ServiceBinding.first(guid: service_binding_2.guid)).to be_nil
      end

      it 'does not make any requests to the service broker' do
        service.purge(event_repository)
        expect(a_request(:delete, /.*/)).not_to have_been_made
      end

      it 'does not mark v2 apps for restaging that were bound to the deleted service' do
        ProcessModelFactory.make(app: service_binding.app, type: 'web')
        expect { service.purge(event_repository) }.not_to change { service_binding.v2_app.reload.needs_staging? }.from(false)
      end

      context 'there is a service instance with state `in progress`' do
        before do
          service_instance.save_with_new_operation({}, state: VCAP::CloudController::ManagedServiceInstance::IN_PROGRESS_STRING)
        end

        it 'destroys all models that depend on it' do
          service.purge(event_repository)

          expect(Service.find(guid: service.guid)).to be_nil
          expect(ServicePlan.first(guid: service_plan.guid)).to be_nil
          expect(ServicePlan.first(guid: service_plan_2.guid)).to be_nil
          expect(ServicePlanVisibility.first(guid: service_plan_visibility.guid)).to be_nil
          expect(ServicePlanVisibility.first(guid: service_plan_visibility_2.guid)).to be_nil
          expect(ServiceInstance.first(guid: service_instance.guid)).to be_nil
          expect(ServiceInstance.first(guid: service_instance_2.guid)).to be_nil
          expect(ServiceBinding.first(guid: service_binding.guid)).to be_nil
          expect(ServiceBinding.first(guid: service_binding_2.guid)).to be_nil
        end
      end

      context 'when deleting a service instance fails' do
        let(:service) { create(:service) }

        before do
          allow_any_instance_of(VCAP::CloudController::ServiceInstance).to receive(:destroy).and_raise('Boom')
        end

        it 'raises the same error' do
          expect do
            service.purge(event_repository)
          end.to raise_error(RuntimeError, /Boom/)
        end
      end

      context 'when deleting a service plan fails' do
        let(:service) { create(:service) }

        before do
          allow_any_instance_of(VCAP::CloudController::ServicePlan).to receive(:destroy).and_raise('Boom')
        end

        it 'rolls back the transaction and does not destroy any records' do
          begin
            service.purge(event_repository)
          rescue StandardError
            nil
          end

          expect(Service.find(guid: service.guid)).to be
          expect(ServicePlan.first(guid: service_plan.guid)).to be
          expect(ServicePlan.first(guid: service_plan_2.guid)).to be
          expect(ServicePlanVisibility.first(guid: service_plan_visibility.guid)).to be
          expect(ServicePlanVisibility.first(guid: service_plan_visibility_2.guid)).to be
          expect(ServiceInstance.first(guid: service_instance.guid)).to be
          expect(ServiceInstance.first(guid: service_instance_2.guid)).to be
          expect(ServiceBinding.first(guid: service_binding.guid)).to be
          expect(ServiceBinding.first(guid: service_binding_2.guid)).to be
        end

        it "does not leave the service in 'purging' state" do
          begin
            service.purge(event_repository)
          rescue StandardError
            nil
          end
          expect(service.reload.purging).to be false
        end
      end
    end

    describe '.organization_visible' do
      it 'returns plans that are visible to the organization' do
        hidden_private_plan = create(:service_plan, public: false)
        hidden_private_service = hidden_private_plan.service
        visible_public_plan = create(:service_plan, public: true)
        visible_public_service = visible_public_plan.service
        visible_private_plan = create(:service_plan, public: false)
        visible_private_service = visible_private_plan.service

        organization = create(:organization)
        create(:service_plan_visibility, organization: organization, service_plan: visible_private_plan)

        visible = Service.organization_visible(organization).all
        expect(visible).to include(visible_public_service)
        expect(visible).to include(visible_private_service)
        expect(visible).not_to include(hidden_private_service)
      end
    end

    describe '.space_or_org_visible_for_user' do
      let(:org) { create(:organization) }
      let(:space) { create(:space, organization: org) }
      let(:dev) { make_developer_for_space(space) }

      let(:expected_service_names) { [@private_service, @visible_service].map(&:label) }

      before do
        @private_broker = create(:service_broker, space:)
        @private_service = create(:service, service_broker: @private_broker, active: true, label: 'Private Service')
        @private_plan = create(:service_plan, service: @private_service, public: false, name: 'Private Plan')

        @public_broker = create(:service_broker)
        @visible_service = create(:service, service_broker: @public_broker, active: true, label: 'Visible Service')
        @visible_plan = create(:service_plan, service: @visible_service, public: true, active: true, name: 'Visible Plan')
        @hidden_service = create(:service, service_broker: @public_broker, active: true, label: 'Hidden Service')
        @hidden_plan = create(:service_plan, service: @hidden_service, public: false, name: 'Hidden Plan')
      end

      it 'returns services that are visible to the spaces org and to the user in that space' do
        visible_services = Service.space_or_org_visible_for_user(space, dev).all
        expected_service_names = [@private_service, @visible_service].map(&:label)
        expect(visible_services.map(&:label)).to match_array expected_service_names
      end

      it 'only returns private broker services to Space<Users>' do
        visible_services = Service.space_or_org_visible_for_user(space, dev).all
        expect(visible_services.map(&:label)).to match_array expected_service_names
      end

      it 'only returns private broker services to Space</Developers>' do
        auditor = make_developer_for_space(space)
        visible_services = Service.space_or_org_visible_for_user(space, auditor).all
        expect(visible_services.map(&:label)).to match_array expected_service_names
      end

      it 'only returns private broker services to Space<Managers>' do
        manager = make_manager_for_space(space)
        visible_services = Service.space_or_org_visible_for_user(space, manager).all
        expect(visible_services.map(&:label)).to match_array expected_service_names
      end

      it 'only returns private broker services to Organization<Users>' do
        user = make_user_for_org(space.organization)
        visible_services = Service.space_or_org_visible_for_user(space, user).all
        expect(visible_services.map(&:label)).to contain_exactly(@visible_service.label)
      end
    end

    describe '.public_visible' do
      it 'returns services that have a plan that is public and active' do
        public_active_service = create(:service, active: true)
        create(:service_plan, active: true, public: true, service: public_active_service)

        private_active_service = create(:service, active: true)
        create(:service_plan, active: true, public: false, service: private_active_service)

        public_inactive_service = create(:service, active: false)
        create(:service_plan, active: false, public: true, service: public_inactive_service)

        private_inactive_service = create(:service, active: false)
        create(:service_plan, active: false, public: false, service: private_inactive_service)

        public_visible = Service.public_visible.all
        expect(public_visible).to eq [public_active_service]
      end
    end

    describe '#route_service?' do
      context 'when requires include "route_forwarding"' do
        let(:service) { create(:service, requires: ['route_forwarding']) }

        it 'returns true' do
          expect(service).to be_route_service
        end
      end

      context 'when requires does not include "route_forwarding"' do
        let(:service) { create(:service, requires: []) }

        it 'returns false' do
          expect(service).not_to be_route_service
        end
      end
    end

    describe '#shareable?' do
      context 'when the service metadata include shareable true' do
        let(:service) { create(:service, extra: '{"shareable":true}') }

        it 'returns true' do
          expect(service).to be_shareable
        end
      end

      context 'when the service metadata include shareable false' do
        let(:service) { create(:service, extra: '{"shareable":false}') }

        it 'returns false' do
          expect(service).not_to be_shareable
        end
      end

      context 'when the service does not include the shareable field in metadata' do
        let(:service) { create(:service, extra: '{"other-key": "value"}') }

        it 'returns false' do
          expect(service).not_to be_shareable
        end
      end

      context 'when the service metadata is nil' do
        let(:service) { create(:service, extra: nil) }

        it 'returns false' do
          expect(service).not_to be_shareable
        end
      end

      context 'when extra contains malformed json' do
        let(:service) { create(:service, extra: '{"not-json"}') }

        it 'returns false' do
          expect(service).not_to be_shareable
        end
      end
    end

    describe '#client' do
      let(:service) { create(:service, service_broker: create(:service_broker)) }

      it 'returns a broker client' do
        fake_client = double(VCAP::Services::ServiceBrokers::V2::Client)
        allow(service.service_broker).to receive(:client).and_return(fake_client)

        client = service.client
        expect(client).to eq(fake_client)
      end

      context 'when the purging field is true' do
        let(:service) { create(:service, purging: true) }

        it 'returns a null broker client' do
          expect(service.client).to be_a(VCAP::Services::ServiceBrokers::NullClient)
        end
      end
    end

    describe '#public' do
      it 'is false when there are no service plans' do
        service_offering = create(:service)
        expect(service_offering.public?).to be false
      end

      it 'is false when there are non-public service plans' do
        service_offering = create(:service)
        create(:service_plan, public: false, service: service_offering)
        expect(service_offering.public?).to be false
      end

      it 'is true when there are public service plans' do
        service_offering = create(:service)
        create(:service_plan, public: true, service: service_offering)
        expect(service_offering.public?).to be true
      end
    end
  end
end
