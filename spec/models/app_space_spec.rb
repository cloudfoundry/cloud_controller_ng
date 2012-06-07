# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::AppSpace do
  it_behaves_like "a CloudController model", {
    :required_attributes => [:name, :organization],
    :unique_attributes   => [:organization, :name],
    :stripped_string_attributes => :name,
    :many_to_one => {
      :organization      => lambda { |app_space| VCAP::CloudController::Models::Organization.make }
    },
    :one_to_zero_or_more => {
      :apps              => lambda { |app_space| VCAP::CloudController::Models::App.make },
      :service_instances => lambda { |app_space| VCAP::CloudController::Models::ServiceInstance.make },
    },
    :many_to_zero_or_more => {
      :developers        => lambda { |app_space| make_user_for_app_space(app_space) },
    }
  }

  context "bad relationships" do
    let(:app_space) { Models::AppSpace.make }

    context "developers" do
      it "should not get associated with a developer that isn't a member of the org" do
        wrong_org = Models::Organization.make
        user = make_user_for_org(wrong_org)

        lambda {
          app_space.add_developer user
        }.should raise_error Models::AppSpace::InvalidDeveloperRelation
      end
    end
  end
end
