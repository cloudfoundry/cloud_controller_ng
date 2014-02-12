require "spec_helper"

module VCAP::CloudController
  describe Service, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes  => [:label, :description, :bindable],
      :required_attribute_error_message => {
        :label => 'name is required'
      },
      :unique_attributes    => [ [:label, :provider] ],
      :stripped_string_attributes => [:label, :provider],
      :one_to_zero_or_more   => {
        :service_plans      => {
          :delete_ok => true,
          :create_for => lambda { |_| ServicePlan.make }
        }
      }
    }

    describe "validation" do
      context 'when the unique_id is not unique' do
        let(:existing_service) { Service.make }
        let(:service) { Service.make_unsaved(unique_id: existing_service.unique_id) }

        it 'is not valid' do
          expect(service).not_to be_valid
        end

        it 'raises an error on save' do
          expect { service.save }.
            to raise_error(Sequel::ValidationFailed, 'service id must be unique')
        end
      end

      context 'when the provider is nil' do
        it 'maintains the uniqueness of the label key' do
          existing_service = Service.make_unsaved(label: 'other', provider: '').save
          expect {
            Service.make_unsaved(label: existing_service.label, provider: '').save
          }.to raise_error('service name must be unique')

          other_service = Service.make_unsaved(label: existing_service.label + ' label', provider: '').save
          expect {
            other_service.update(label: existing_service.label)
          }.to raise_error('service name must be unique')
        end
      end

      context 'when the provider is present' do
        it 'maintains the uniqueness of the compound key [label, provider]' do
          expect {
            Service.make_unsaved(label: 'blah', provider: 'blah').save
            Service.make_unsaved(label: 'blah', provider: 'blah').save
          }.to raise_error('label and provider is taken')
        end
      end

      context 'when the sso_client_id is not unique' do
        let(:existing_service) { Service.make }
        let(:service) { Service.make_unsaved(sso_client_id: existing_service.sso_client_id) }

        it 'is not valid' do
          expect(service).not_to be_valid
        end

        it 'raises an error on save' do
          expect { service.save }.
            to raise_error(Sequel::ValidationFailed, 'dashboard client id must be unique')
        end
      end
    end

    it 'ensures that blank provider values will be treated as nil' do
      service = Service.make_unsaved(provider: '').save
      expect(service.provider).to be_nil
    end

    describe "#destroy" do
      let!(:service) { Service.make }
      subject { service.destroy(savepoint: true) }

      it "doesn't remove the associated ServiceAuthToken" do
        # XXX services don't always have a token, unlike what the fixture implies
        expect {
          subject
        }.to_not change {
          ServiceAuthToken.count(:label => service.label, :provider => service.provider)
        }
      end
    end

    describe "serialization" do
      let(:extra) { 'extra' }
      let(:unique_id) { 'glue-factory' }
      let(:service) { Service.new_from_hash(extra: extra, unique_id: unique_id, bindable: true) }

      it "allows mass assignment of extra" do
        service.extra.should == extra
      end

      it "allows export of extra"  do
        Yajl::Parser.parse(service.to_json)["extra"].should == extra
      end

      it "allows mass assignment of unique_id" do
        service.unique_id.should == unique_id
      end

      it "allows export of unique_id" do
        Yajl::Parser.parse(service.to_json)["unique_id"].should == unique_id
      end

      it "allows export of bindable" do
        Yajl::Parser.parse(service.to_json)["bindable"].should == true
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
        records(admin_user).should include(private_service, public_service)
      end

      it "only returns public services for nonadmins" do
        records(nonadmin_user).should include(public_service)
        records(nonadmin_user).should_not include(private_service)
      end

      it "returns private services if a user can see a plan inside them" do
        ServicePlanVisibility.create(
          organization: nonadmin_org,
          service_plan: private_plan,
        )
        records(nonadmin_user).should include(private_service, public_service)
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
        service.should be_v2
      end

      it "returns false when the service is not associated with a broker" do
        service = Service.make(service_broker: nil)
        service.should_not be_v2
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
          http_client_stub = VCAP::CloudController::ServiceBroker::V1::HttpClient.new
          expect(http_client_stub).not_to have_received(:unbind)
          expect(http_client_stub).not_to have_received(:deprovision)
        end

        it 'marks apps for restaging that were bound to the deleted service' do
          service_binding.app.update(package_state: 'STAGED')
          expect { service.purge }.to change{ service_binding.app.reload.pending? }.to(true)
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

        it 'marks apps for restaging that were bound to the deleted service' do
          service_binding.app.update(package_state: 'STAGED')
          expect { service.purge }.to change{ service_binding.app.reload.pending? }.to(true)
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
          expect(service.reload.purging).to be_false
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
        visible.should include(visible_public_service)
        visible.should include(visible_private_service)
        visible.should_not include(hidden_private_service)
      end
    end

    describe '#client' do
      context 'when the purging field is true' do
        let(:service) { Service.make(purging: true) }

        it 'returns a null broker client' do
          expect(service.client).to be_a(VCAP::CloudController::ServiceBrokers::NullClient)
        end
      end

      context 'for a v1 service' do
        let(:service) { Service.make(service_broker: nil) }

        it 'returns a v1 broker client' do
          v1_client = double(ServiceBroker::V1::Client)
          ServiceBroker::V1::Client.stub(:new).and_return(v1_client)

          client = service.client
          client.should == v1_client

          expect(ServiceBroker::V1::Client).to have_received(:new).with(
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
          v2_client = double(ServiceBroker::V2::Client)
          service.service_broker.stub(:client).and_return(v2_client)

          client = service.client
          client.should == v2_client
        end
      end
    end
  end
end
