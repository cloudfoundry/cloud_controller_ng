require "spec_helper"
require "thread"

describe "Cloud controller", type: :integration, monitoring: true do
  context "when configured to use development mode" do
    let(:port) { 8181 }

    let (:newrelic_config) { "developer" }

    let (:config_file) {
      File.expand_path(File.join(File.dirname(__FILE__), "../fixtures/config/newrelic_#{newrelic_config}.yml"))
    }

    before do
      start_nats(debug: false)
      opts = {
        debug: false,
        config: "spec/fixtures/config/port_8181_config.yml",
        extra_command_args: "-d",
        env: {
          "NRCONFIG" => config_file
        }
      }
      start_cc(opts)
    end

    after do
      stop_cc
      stop_nats
    end

    it "reports the transaction information in /newrelic" do
      info_response = make_get_request("/info", {}, port)
      expect(info_response.code).to eq("200")
      newrelic_response = make_get_request("/newrelic", {}, port)
      expect(newrelic_response.code).to eq("200")
      expect(newrelic_response.body).to include("/info")
    end
  end
end
