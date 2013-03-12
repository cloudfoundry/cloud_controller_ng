require "spec_helper"
require "net/http"

describe "Cloud controller", :type => :integration do
  before(:all) { WebMock.allow_net_connect! }
  start_nats
  start_cc

  it "responds to /info" do
    result = Net::HTTP.get_response(URI.parse("http://localhost:8181/info"))
    result.code.should == "200"

    JSON.parse(result.body).tap do |r|
      r["version"].should == 2
    end
  end
end
