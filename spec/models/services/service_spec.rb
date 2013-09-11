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
  end
end
