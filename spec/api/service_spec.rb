# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Service do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/services",
    :model                => VCAP::CloudController::Models::Service,
    :basic_attributes     => [:label, :provider, :url, :description, :version, :info_url, :cf_plan_id],
    :required_attributes  => [:label, :provider, :url, :description, :version],
    :unique_attributes    => [:label, :provider],
    :one_to_many_collection_ids  => {
      :service_plans => lambda { |service| VCAP::CloudController::Models::ServicePlan.make }
    }
  }

  describe "service enumeration" do
    num_svc_without_id = 5
    num_svc_with_id = 3
    num_svc = num_svc_without_id + num_svc_with_id

    describe "GET /v2/services" do
      before do
        num_svc_without_id.times do
          Models::Service.make
        end

        num_svc_with_id.times do
          Models::Service.make(:cf_plan_id => "abc")
        end

        @user = VCAP::CloudController::Models::User.make
        @cf_admin = VCAP::CloudController::Models::User.make(:admin => true)
      end

      it "should return all instances to an admin" do
        get "/v2/services", {}, headers_for(@cf_admin)
        last_response.status.should == 200
        decoded_response["total_results"].should == num_svc
      end

      it "should return only instances with cf_plan_id to standard users" do
        get "/v2/services", {}, headers_for(@user)
        last_response.status.should == 200
        decoded_response["total_results"].should == num_svc_with_id
      end
    end
  end
end
end
