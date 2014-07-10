require "spec_helper"

module VCAP::CloudController
  describe Service, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :service_broker }
      it { is_expected.to have_associated :service_plans }

      it "has associated service_auth_token" do
        service = Service.make
        expect(service.reload.service_auth_token).to be_a ServiceAuthToken
      end
    end

    describe "Validations" do
      it { is_expected.to validate_presence :label, message: 'Service name is required' }
      it { is_expected.to validate_presence :description, message: 'is required' }
      it { is_expected.to validate_presence :bindable, message: 'is required' }
      it { is_expected.to validate_uniqueness [:label, :provider], message: 'is taken' }
      it { is_expected.to validate_uniqueness :unique_id, message: 'Service ids must be unique' }
      it { is_expected.to strip_whitespace :label }
      it { is_expected.to strip_whitespace :provider }

      context 'when the unique_id is not unique' do
        let(:existing_service) { Service.make }
        let(:service) { Service.make_unsaved(unique_id: existing_service.unique_id) }

        it 'is not valid' do
          expect(service).not_to be_valid
        end

        it 'raises an error on save' do
          expect { service.save }.
            to raise_error(Sequel::ValidationFailed, 'Service ids must be unique')
        end
      end

      describe "urls" do
        it "validates format of url" do
          service = Service.make_unsaved(url: "bogus_url")
          expect(service).to_not be_valid
          expect(service.errors.on(:url)).to include "must be a valid url"
        end

        it "validates format of info_url" do
          service = Service.make_unsaved(info_url: "bogus_url")
          expect(service).to_not be_valid
          expect(service.errors.on(:info_url)).to include "must be a valid url"
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
          existing_service = Service.make_unsaved(label: 'other', provider: 'core').save
          expect {
            Service.make_unsaved(:v2, label: existing_service.label, service_broker: ServiceBroker.make).save
          }.not_to raise_error
        end
      end

      context 'for a v1 service' do
        it 'maintains the uniqueness of the compound key [label, provider]' do
          expect {
            Service.make_unsaved(label: 'blah', provider: 'blah').save
            Service.make_unsaved(label: 'blah', provider: 'blah').save
          }.to raise_error('label and provider is taken')
        end
      end
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :label, :provider, :url, :description, :long_description, :version, :info_url, :active, :bindable,
                                    :unique_id, :extra, :tags, :requires, :documentation_url, :service_broker_guid }
      it { is_expected.to import_attributes :label, :provider, :url, :description, :long_description, :version, :info_url,
                                    :active, :bindable, :unique_id, :extra, :tags, :requires, :documentation_url }
    end

    it 'ensures that blank provider values will be treated as nil' do
      service = Service.make_unsaved(provider: '').save
      expect(service.provider).to be_nil
    end

    describe "#destroy" do
      let!(:service) { Service.make }
      subject { service.destroy }

      it "doesn't remove the associated ServiceAuthToken" do
        # XXX services don't always have a token, unlike what the fixture implies
        expect {
          subject
        }.to_not change {
          ServiceAuthToken.count(:label => service.label, :provider => service.provider)
        }
      end
    end

    describe "#user_visibility_filter" do
      let(:private_service) { Service.make }
      let(:public_service) { Service.make }
      let(:nonadmin_org) { Organization.make }
      let(:admin_user) { User.make(:admin => true, :active => true) }
      let(:nonadmin_user) { User.make(:admin => false, :active => true) }
      let!(:private_plan) { ServicePlan.make :service => private_service, :public => false }
      before do
        ServicePlan.make :service => public_service, :public => true
        ServicePlan.make :service => public_service, :public => false
        VCAP::CloudController::SecurityContext.set(admin_user, {'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE]} )
        nonadmin_user.add_organization nonadmin_org
        VCAP::CloudController::SecurityContext.clear
      end

      def records(user)
        Service.user_visible(user, user.admin?).all
      end

      it "returns all services for admins" do
        expect(records(admin_user)).to include(private_service, public_service)
      end

      it "only returns public services for nonadmins" do
        expect(records(nonadmin_user)).to include(public_service)
        expect(records(nonadmin_user)).not_to include(private_service)
      end

      it "returns private services if a user can see a plan inside them" do
        ServicePlanVisibility.create(
          organization: nonadmin_org,
          service_plan: private_plan,
        )
        expect(records(nonadmin_user)).to include(private_service, public_service)
      end

      it "returns public services for unauthenticated users" do
        records = Service.user_visible(nil).all
        expect(records).to eq [public_service]
      end
    end

    describe "#tags" do
      context 'null tags in the database' do
        it 'returns an empty array' do
          service = Service.make(tags: nil)
          expect(service.tags).to eq []
        end
      end
    end

    describe "#requires" do
      context 'null requires in the database' do
        it 'returns an empty array' do
          service = Service.make(requires: nil)
          expect(service.requires).to eq []
        end
      end
    end

    describe "#documentation_url" do
      context 'with a URL in the database' do
        it 'returns the appropriate URL' do
          sham_url = Sham.url
          service = Service.make(documentation_url: sham_url)
          expect(service.documentation_url).to eq sham_url
        end
      end
    end

    describe "#long_description" do
      context 'with a long description in the database' do
        it 'return the appropriate long description' do
          sham_long_description = Sham.long_description
          service = Service.make(long_description: sham_long_description)
          expect(service.long_description).to eq sham_long_description
        end
      end
    end

    describe "#v2?" do
      it "returns true when the service is associated with a broker" do
        service = Service.make(service_broker: ServiceBroker.make)
        expect(service).to be_v2
      end

      it "returns false when the service is not associated with a broker" do
        service = Service.make(service_broker: nil)
        expect(service).not_to be_v2
      end
    end

    describe '#purge' do
      let!(:service_plan) { ServicePlan.make(service: service) }
      let!(:service_plan_visibility) { ServicePlanVisibility.make(service_plan: service_plan) }
      let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
      let!(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

      let!(:service_plan_2) { ServicePlan.make(service: service) }
      let!(:service_plan_visibility_2) { ServicePlanVisibility.make(service_plan: service_plan_2) }
      let!(:service_instance_2) { ManagedServiceInstance.make(service_plan: service_plan_2) }
      let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance_2) }

      before do
        stub_request(:delete, /.*/).to_return(body: '{}', status: 200)
      end

      context 'for v1 services' do
        let!(:service) { Service.make(:v1) }

        it 'destroys all models that depend on it' do
          service.purge

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
          service.purge
          http_client_stub = VCAP::Services::ServiceBrokers::V1::HttpClient.new
          expect(http_client_stub).not_to have_received(:unbind)
          expect(http_client_stub).not_to have_received(:deprovision)
        end

        it 'does not mark apps for restaging that were bound to the deleted service' do
          service_binding.app.update(package_state: 'STAGED')
          expect { service.purge }.not_to change{ service_binding.app.reload.pending? }
        end
      end

      context 'for v2 services' do
        let!(:service) { Service.make(:v2) }

        it 'destroys all models that depend on it' do
          service.purge

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
          service.purge
          expect(a_request(:delete, /.*/)).not_to have_been_made
        end

        it 'does not mark apps for restaging that were bound to the deleted service' do
          service_binding.app.update(package_state: 'STAGED')
          expect { service.purge }.not_to change{ service_binding.app.reload.pending? }
        end
      end

      context 'when deleting one of the records fails' do
        let(:service) { Service.make }

        before do
          allow_any_instance_of(VCAP::CloudController::ServicePlan).to receive(:destroy).and_raise('Boom')
        end

        it 'rolls back the transaction and does not destroy any records' do
          service.purge rescue nil

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
          service.purge rescue nil
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

    describe '.public_visible' do
      it 'returns services that have a plan that is public and active' do
        public_active_service = Service.make(active: true)
        public_active_plan = ServicePlan.make(active: true, public: true, service: public_active_service)

        private_active_service = Service.make(active: true)
        private_active_plan = ServicePlan.make(active: true, public: false, service: private_active_service)

        public_inactive_service = Service.make(active: false)
        public_inactive_plan = ServicePlan.make(active: false, public: true, service: public_inactive_service)

        private_inactive_service = Service.make(active: false)
        private_inactive_plan = ServicePlan.make(active: false, public: false, service: private_inactive_service)

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
        let(:service) { Service.make(service_broker: nil) }

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
        let(:service) { Service.make(service_broker: ServiceBroker.make) }

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
