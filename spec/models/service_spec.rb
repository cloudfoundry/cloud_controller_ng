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
      let(:service) { Models::Service.new_from_hash(extra: "extra") }

      it "allows mass assignment of extra" do
         service.extra.should == 'extra'
      end

      it "allows export of extra"  do
         Yajl::Parser.parse(service.to_json)["extra"].should == 'extra'
      end

    end
  end
end
