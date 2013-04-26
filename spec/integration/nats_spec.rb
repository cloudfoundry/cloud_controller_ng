require "spec_helper"
include IntegrationSetupHelpers
include IntegrationSetup

describe "NATS", :type => :integration do
  start_nats
  start_cc(:env => {"NATS_MAX_RECONNECT_ATTEMPTS" => "0"}, :debug => true)

  context "When NATS fails" do
    before do
      Process.kill("KILL", @nats_pid)
      sleep 3
    end

    it "does not exit" do
      make_http_request("/info").tap do |r|
        r.code.should == "200"
      end
    end
  end
end