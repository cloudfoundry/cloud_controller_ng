# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::ServicePlan do
  it_behaves_like "a CloudController model", {
    :required_attributes => [:name, :description, :service],
    :unique_attributes   => [:service, :name],
    :many_to_one => {
      :service => {
        :delete_ok => true,
        :create_for => lambda { |service_plan| VCAP::CloudController::Models::Service.make },
      },
    },
    :one_to_zero_or_more  => {
      :service_instances => lambda { |service_plan| VCAP::CloudController::Models::ServiceInstance.make }
    },
  }

  describe "conversions" do
    describe "name" do
      it "should upcase and strip the name" do
        p = Models::ServicePlan.make(:name => " d100 ")
        p.name.should == "D100"
      end
    end
  end
end
