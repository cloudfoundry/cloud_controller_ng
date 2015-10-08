require 'spec_helper'

module VCAP::CloudController
  describe Service, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :service_broker }
      it { is_expected.to have_associated :service_plans }

      context 'for a v1 service' do
        it 'has associated service_auth_token' do
          service = Service.make(:v1)
          expect(service.reload.service_auth_token).to be_a ServiceAuthToken
        end
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :label, message: 'Service name is required' }
      it { is_expected.to validate_presence :description, message: 'is required' }
      it { is_expected.to validate_presence :bindable, message: 'is required' }
      it { is_expected.to validate_uniqueness :unique_id, message: 'Service ids must be unique' }
      it { is_expected.to strip_whitespace :label }
      it { is_expected.to strip_whitespace :provider }

      context 'for a v1 service' do
        it { is_expected.to validate_uniqueness [:label, :provider], message: 'is taken', make: [:v1] }
      end

      context 'when the unique_id is not unique' do
        let(:existing_service) { Service.make }
        let(:service) { Service.make_unsaved(:v1, unique_id: existing_service.unique_id) }

        it 'is not valid' do
          expect(service).not_to be_valid
        end

        it 'raises an error on save' do
          expect { service.save }.
            to raise_error(Sequel::ValidationFailed, 'Service ids must be unique')
        end
      end

      describe 'urls' do
        it 'validates format of url' do
          service = Service.make_unsaved(url: 'bogus_url', service_broker: nil)
          expect(service).to_not be_valid
          expect(service.errors.on(:url)).to include 'must be a valid url'
        end

        it 'validates format of info_url' do
          service = Service.make_unsaved(info_url: 'bogus_url', service_broker: nil)
          expect(service).to_not be_valid
          expect(service.errors.on(:info_url)).to include 'must be a valid url'
        end
      end

      context 'for a v2 service' do
        let(:service_broker) { ServiceBroker.make }
        it 'maintains the uniqueness of the label key' do
          existing_service = Service.make_unsaved(:v2, label: 'other', service_broker: service_broker).save

          expect {
            Service.make_unsaved(:v2, label: existing_service.label, service_broker: service_broker).save
          }.to raise_error('Service name must be unique')

          other_service = Service.make_unsaved(:v2,
            label: existing_service.label + ' label',
            service_broker: service_broker
          ).save

          expect {
            other_service.update(label: existing_service.label)
          }.to raise_error('Service name must be unique')
        end

        it 'allows the service to have the same label as a v1 service' do
          existing_service = Service.make_unsaved(:v1, label: 'other', provider: 'core').save
          expect {
            Service.make_unsaved(:v2, label: existing_service.label, service_broker: ServiceBroker.make).save
          }.not_to raise_error
        end
      end

      context 'for a v1 service' do
        it 'maintains the uniqueness of the compound key [label, provider]' do
          expect {
            Service.make_unsaved(:v1, label: 'blah', provider: 'blah').save
            Service.make_unsaved(:v1, label: 'blah', provider: 'blah').save
          }.to raise_error('label and provider is taken')
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :label, :provider, :url, :description, :long_description, :version, :info_url, :active, :bindable,
                                    :unique_id, :extra, :tags, :requires, :documentation_url, :service_broker_guid, :plan_updateable
      }
      it { is_expected.to import_attributes :label, :provider, :url, :description, :long_description, :version, :info_url,
                                    :active, :bindable, :unique_id, :extra, :tags, :requires, :documentation_url, :plan_updateable
      }
    end

    it 'ensures that blank provider values will be treated as nil' do
      service = Service.make_unsaved(provider: '', service_broker: nil).save
      expect(service.provider).to be_nil
    end

    describe '#destroy' do
      let!(:service) { Service.make }
      subject { service.destroy }

      it "doesn't remove the associated ServiceAuthToken" do
        # XXX services don't always have a token, unlike what the fixture implies
        expect {
          subject
        }.to_not change {
                   ServiceAuthToken.count(label: service.label, provider: service.provider)
                 }
      end
    end

    describe '#user_visibility_filter' do
      let(:private_service) { Service.make }
      let(:public_service) { Service.make }
      let(:nonadmin_org) { Organization.make }
      let(:admin_user) { User.make }
      let(:nonadmin_user) { User.make }
      let!(:private_plan) { ServicePlan.make service: private_service, public: false }
      before do
        ServicePlan.make service: public_service, public: true
        ServicePlan.make service: public_service, public: false
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
          service_plan: private_plan,
        )
        expect(records(nonadmin_user)).to include(private_service, public_service)
      end

      it 'returns public services for unauthenticated users' do
        records = Service.user_visible(nil).all
        expect(records).to eq [public_service]
      end

      describe 'services from private brokers' do
        it 'does not return the services to users with no roles in the space' do
          space = Space.make
          space_developer = User.make

          space.organization.add_user space_developer

          private_broker = ServiceBroker.make space: space
          service = Service.make(service_broker: private_broker, active: true)
          ServicePlan.make(service: service, active: true, public: false)

          records = Service.user_visible(space_developer).all
          expect(records.map(&:guid)).not_to include service.guid
        end

        it "returns services from private brokers to space developers in that private broker's space" do
          space = Space.make
          space_developer = User.make

          space.organization.add_user space_developer

          space.add_developer space_developer

          private_broker = ServiceBroker.make space: space
          service = Service.make(service_broker: private_broker, active: true)
          ServicePlan.make(service: service, active: true, public: false)

          records = Service.user_visible(space_developer).all
          expect(records.map(&:guid)).to include service.guid
        end

        it "returns services from private brokers to space auditors in that private broker's space" do
          space = Space.make
          space_auditor = User.make

          space.organization.add_user space_auditor

          space.add_auditor space_auditor

          private_broker = ServiceBroker.make space: space
          service = Service.make(service_broker: private_broker, active: true)
          ServicePlan.make(service: service, active: true, public: false)
          records = Service.user_visible(space_auditor).all
          expect(records.map(&:guid)).to include service.guid
        end

        it "returns services from private brokers to space managers in that private broker's space" do
          space = Space.make
          space_manager = User.make

          space.organization.add_user space_manager

          space.add_manager space_manager

          private_broker = ServiceBroker.make space: space
          service = Service.make(service_broker: private_broker, active: true)
          ServicePlan.make(service: service, active: true, public: false)
          records = Service.user_visible(space_manager).all
          expect(records).to include service
        end
      end
    end

    describe '#tags' do
      it 'returns the provided service tags' do
        service = Service.make(tags: %w(a b c))
        expect(service.tags).to match_array(%w(a b c))
      end

      context 'null tags in the database' do
        it 'returns an empty array' do
          service = Service.make(tags: nil)
          expect(service.tags).to eq []
        end
      end
    end

    describe '#requires' do
      context 'null requires in the database' do
        it 'returns an empty array' do
          service = Service.make(requires: nil)
          expect(service.requires).to eq []
        end
      end
    end

    describe '#documentation_url' do
      context 'with a URL in the database' do
        it 'returns the appropriate URL' do
          sham_url = Sham.url
          service = Service.make(documentation_url: sham_url)
          expect(service.documentation_url).to eq sham_url
        end
      end
    end

    describe '#long_description' do
      context 'with a long description in the database' do
        it 'return the appropriate long description' do
          sham_long_description = Sham.long_description
          service = Service.make(long_description: sham_long_description)
          expect(service.long_description).to eq sham_long_description
        end
      end
    end

    describe '#v2?' do
      it 'returns true when the service is associated with a broker' do
        service = Service.make(service_broker: ServiceBroker.make)
        expect(service).to be_v2
      end

      it 'returns false when the service is not associated with a broker' do
        service = Service.make(service_broker: nil)
        expect(service).not_to be_v2
      end
    end

    describe '#purge' do
      let!(:event_repository) { double(Repositories::Services::ServiceUsageEventRepository) }
      let!(:service_plan) { ServicePlan.make(service: service) }
      let!(:service_plan_visibility) { ServicePlanVisibility.make(service_plan: service_plan) }
      let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
      let!(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

      let!(:service_plan_2) { ServicePlan.make(service: service) }
      let!(:service_plan_visibility_2) { ServicePlanVisibility.make(service_plan: service_plan_2) }
      let!(:service_instance_2) { ManagedServiceInstance.make(service_plan: service_plan_2) }
      let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance_2) }

      before do
        allow(Repositories::Services::ServiceUsageEventRepository).to receive(:new).and_return(event_repository)
        allow(event_repository).to receive(:record_service_binding_event)
        allow(event_repository).to receive(:deleted_event_from_service_instance)
        allow(event_repository).to receive(:record_service_instance_event)
      end

      context 'for v1 services' do
        let!(:service) { Service.make(:v1) }

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
          http_client_stub = VCAP::Services::ServiceBrokers::V1::HttpClient.new
          expect(http_client_stub).not_to have_received(:unbind)
          expect(http_client_stub).not_to have_received(:deprovision)
        end

        it 'does not mark apps for restaging that were bound to the deleted service' do
          service_binding.app.update(package_state: 'STAGED')
          expect { service.purge(event_repository) }.not_to change { service_binding.app.reload.pending? }
        end
      end

      context 'for v2 services' do
        let!(:service) { Service.make(:v2) }

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

        it 'does not mark apps for restaging that were bound to the deleted service' do
          service_binding.app.update(package_state: 'STAGED')
          expect { service.purge(event_repository) }.not_to change { service_binding.app.reload.pending? }
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
      end

      context 'when deleting a service instance fails' do
        let(:service) { Service.make }

        before do
          allow_any_instance_of(VCAP::CloudController::ServiceInstance).to receive(:destroy).and_raise('Boom')
        end

        it 'raises the same error' do
          expect {
            service.purge(event_repository)
          }.to raise_error(RuntimeError, /Boom/)
        end
      end

      context 'when deleting a service plan fails' do
        let(:service) { Service.make }

        before do
          allow_any_instance_of(VCAP::CloudController::ServicePlan).to receive(:destroy).and_raise('Boom')
        end

        it 'rolls back the transaction and does not destroy any records' do
          service.purge(event_repository) rescue nil

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
          service.purge(event_repository) rescue nil
          expect(service.reload.purging).to be false
        end
      end
    end

    describe '.organization_visible' do
      it 'returns plans that are visible to the organization' do
        hidden_private_plan = ServicePlan.make(public: false)
        hidden_private_service = hidden_private_plan.service
        visible_public_plan = ServicePlan.make(public: true)
        visible_public_service = visible_public_plan.service
        visible_private_plan = ServicePlan.make(public: false)
        visible_private_service = visible_private_plan.service

        organization = Organization.make
        ServicePlanVisibility.make(organization: organization, service_plan: visible_private_plan)

        visible = Service.organization_visible(organization).all
        expect(visible).to include(visible_public_service)
        expect(visible).to include(visible_private_service)
        expect(visible).not_to include(hidden_private_service)
      end
    end

    describe '.space_or_org_visible_for_user' do
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:dev) { make_developer_for_space(space) }
      let(:outside_dev) { User.make(admin: false, active: true) }

      before(:each) do
        @private_broker = ServiceBroker.make(space: space)
        @private_service = Service.make(service_broker: @private_broker, active: true, label: 'Private Service')
        @private_plan = ServicePlan.make(service: @private_service, public: false, name: 'Private Plan')

        @public_broker = ServiceBroker.make
        @visible_service = Service.make(service_broker: @public_broker, active: true, label: 'Visible Service')
        @visible_plan = ServicePlan.make(service: @visible_service, name: 'Visible Plan')
        @hidden_service = Service.make(service_broker: @public_broker, active: true, label: 'Hidden Service')
        @hidden_plan = ServicePlan.make(service: @hidden_service, public: false, name: 'Hidden Plan')
      end

      it 'returns services that are visible to the spaces org and to the user in that space' do
        visible_services = Service.space_or_org_visible_for_user(space, dev).all
        expected_service_names = [@private_service, @visible_service].map(&:label)
        expect(visible_services.map(&:label)).to match_array expected_service_names
      end

      it 'only returns private broker services to Space<Managers/Auditors/Developers>' do
        expected_service_names = [@private_service, @visible_service].map(&:label)

        visible_services = Service.space_or_org_visible_for_user(space, dev).all
        expect(visible_services.map(&:label)).to match_array expected_service_names

        auditor = make_developer_for_space(space)
        visible_services = Service.space_or_org_visible_for_user(space, auditor).all
        expect(visible_services.map(&:label)).to match_array expected_service_names

        manager = make_manager_for_space(space)
        visible_services = Service.space_or_org_visible_for_user(space, manager).all
        expect(visible_services.map(&:label)).to match_array expected_service_names

        user = make_user_for_org(space.organization)
        visible_services = Service.space_or_org_visible_for_user(space, user).all
        expect(visible_services.map(&:label)).to match_array [@visible_service.label]
      end
    end

    describe '.public_visible' do
      it 'returns services that have a plan that is public and active' do
        public_active_service = Service.make(active: true)
        ServicePlan.make(active: true, public: true, service: public_active_service)

        private_active_service = Service.make(active: true)
        ServicePlan.make(active: true, public: false, service: private_active_service)

        public_inactive_service = Service.make(active: false)
        ServicePlan.make(active: false, public: true, service: public_inactive_service)

        private_inactive_service = Service.make(active: false)
        ServicePlan.make(active: false, public: false, service: private_inactive_service)

        public_visible = Service.public_visible.all
        expect(public_visible).to eq [public_active_service]
      end
    end

    describe '#client' do
      context 'when the purging field is true' do
        let(:service) { Service.make(purging: true) }

        it 'returns a null broker client' do
          expect(service.client).to be_a(VCAP::Services::ServiceBrokers::NullClient)
        end
      end

      context 'for a v1 service' do
        let(:service) { Service.make(:v1, service_broker: nil) }

        it 'returns a v1 broker client' do
          v1_client = double(VCAP::Services::ServiceBrokers::V1::Client)
          allow(VCAP::Services::ServiceBrokers::V1::Client).to receive(:new).and_return(v1_client)

          client = service.client
          expect(client).to eq(v1_client)

          expect(VCAP::Services::ServiceBrokers::V1::Client).to have_received(:new).with(
              hash_including(
                url: service.url,
                auth_token: service.service_auth_token.token,
                timeout: service.timeout
              )
            )
        end
      end

      context 'for a v2 service' do
        let(:service) { Service.make(:v2, service_broker: ServiceBroker.make) }

        it 'returns a v2 broker client' do
          v2_client = double(VCAP::Services::ServiceBrokers::V2::Client)
          allow(service.service_broker).to receive(:client).and_return(v2_client)

          client = service.client
          expect(client).to eq(v2_client)
        end
      end
    end
  end
end
