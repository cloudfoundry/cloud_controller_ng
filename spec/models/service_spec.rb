# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Service do
    it_behaves_like "a CloudController model", {
      :required_attributes  => [:label, :provider, :url, :description, :version],
      :unique_attributes    => [:label, :provider],
      :stripped_string_attributes => [:label, :provider],
      :one_to_zero_or_more   => {
        :service_plans      => {
          :delete_ok => true,
          :create_for => lambda { |_| Models::ServicePlan.make }
        }
      }
    }

    describe "#destroy" do
      let!(:service) { Models::Service.make }
      subject { service.destroy }

      it "doesn't remove the associated ServiceAuthToken" do
        # XXX services don't always have a token, unlike what the fixture implies
        expect {
          subject
        }.to_not change {
          Models::ServiceAuthToken.count(:label => service.label, :provider => service.provider)
        }
      end
    end

    describe "validation" do
      context "when unique_id is not provided" do
        it "creates a composite unique_id" do
          service = Models::Service.new(provider: "core", label: "ponies")
          service.valid?
          service.unique_id.should == "core_ponies"
        end
      end

      context "when unique_id is provided" do
        it "uses provided unique_id" do
          service = Models::Service.new(provider: "core", label: "ponies", unique_id: "glue-factory")
          service.valid?
          service.unique_id.should == "glue-factory"
        end
      end
    end

    describe "serialization" do
      let(:extra) { 'extra' }
      let(:unique_id) { 'glue-factory' }
      let(:service) { Models::Service.new_from_hash(extra: extra, unique_id: unique_id) }

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
    end

    describe "#user_visibility_filter" do
      let(:private_org) { Models::Organization.make(:can_access_non_public_plans => true) }
      let(:private_service) { Models::Service.make }
      let(:public_service) { Models::Service.make }
      let(:admin_user) { Models::User.make(:admin => true, :active => true) }
      let(:nonadmin_user) { Models::User.make(:admin => false, :active => true) }
      let(:private_user) { Models::User.make(:admin => false, :active => true) }
      before do
        Models::ServicePlan.make :service => private_service, :public => false
        Models::ServicePlan.make :service => public_service, :public => true
        Models::ServicePlan.make :service => public_service, :public => false
        VCAP::CloudController::SecurityContext.set(admin_user)
        private_user.add_organization private_org
        VCAP::CloudController::SecurityContext.clear
      end

      def records(user)
        VCAP::CloudController::SecurityContext.set(user)
        Models::Service.filter(Models::Service.user_visibility_filter(user))
      end

      it "returns all services for admins" do
        records(admin_user).should include(private_service)
        records(admin_user).should include(public_service)
      end

      it "only returns public services for nonadmins" do
        records(nonadmin_user).should include(public_service)
        records(nonadmin_user).should_not include(private_service)
      end

      it "returns private services if a user can see a plan inside them" do
        records(private_user).should include(private_service)
        records(private_user).should include(public_service)
      end
    end
  end
end
