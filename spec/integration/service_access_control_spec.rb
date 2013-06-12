require "spec_helper"

describe "Service access control", :type => :integration do
  before(:all) do
    start_nats debug: false
    start_cc debug: false
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  let!(:service_guid) { create_service }
  let!(:org_guid)     { create_org }
  let!(:plan_guid)    { create_plan(service_guid) }
  let!(:user_guid)    { create_user(org_guid) }

  it "ensures that new plans are private" do
    visible_plan_guids(user_guid).should_not include(plan_guid)
  end
end
