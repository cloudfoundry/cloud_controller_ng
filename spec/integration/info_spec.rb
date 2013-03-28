require "spec_helper"

describe "Cloud controller", :type => :integration do
  start_nats
  start_cc

  it "responds to /info" do
    make_http_request("/info").tap do |r|
      r.code.should == "200"
      r.json_body["version"].should == 2
      r.json_body["description"].should == "Cloud Foundry sponsored by Pivotal"
    end
  end

  it "authenticate and authorize with valid token" do
    unauthorized_token = {"Authorization" => "bearer unauthorized-token"}
    make_http_request("/v2/stacks", unauthorized_token).tap do |r|
      r.code.should == "401"
    end

    authorized_token = {"Authorization" => "bearer #{admin_token}"}
    make_http_request("/v2/stacks", authorized_token).tap do |r|
      r.code.should == "200"
      r.json_body["resources"].should be_a(Array)
    end
  end
end
