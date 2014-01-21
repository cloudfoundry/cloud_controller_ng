require "spec_helper"

module VCAP::CloudController
  describe Service, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes  => [:label, :description, :bindable],
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

        it 'shows a human-readable error message' do
          expect(service).not_to be_valid
          expect(service.errors.on(:unique_id)).to eql(['is taken'])
        end
      end
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
