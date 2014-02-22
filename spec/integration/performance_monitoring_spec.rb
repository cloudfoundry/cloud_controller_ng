require "spec_helper"
require "tempfile"
require "thread"

describe "Cloud controller", type: :integration, monitoring: true do
  context "when configured to use development mode" do
    let(:port) { 8181 }

    let (:newrelic_config_file) {
      File.expand_path(File.join(File.dirname(__FILE__), "../fixtures/config/newrelic.yml"))
    }

    let(:base_cc_config_file) {
      "spec/fixtures/config/port_8181_config.yml"
    }

    before do
      start_nats(debug: false)
      opts = {
        debug: false,
        config: cc_config_file.path,
        env: {
          "NRCONFIG" => newrelic_config_file,
          "RACK_ENV" => "development"
        }
      }
      start_cc(opts)
    end

    after do
      stop_cc
      stop_nats
      cc_config_file.unlink
    end

    context "when developer mode is enabled" do
      let(:cc_config_file) do
        cc_config = YAML.load_file(base_cc_config_file)
        cc_config['development_mode'] = true
        file = Tempfile.new("cc_config.yml")
        file.write(YAML.dump(cc_config))
        file.close
        file
      end

      it "reports the transaction information in /newrelic" do
        info_response = make_get_request("/info", {}, port)
        expect(info_response.code).to eq("200")

        newrelic_response = make_get_request("/newrelic", {}, port)
        expect(newrelic_response.code).to eq("200")
        expect(newrelic_response.body).to include("/info")
      end
    end

    context "when developer mode is not enabled" do
      let(:cc_config_file) do
        cc_config = YAML.load_file(base_cc_config_file)
        cc_config['development_mode'] = false
        file = Tempfile.new("cc_config.yml")
        file.write(YAML.dump(cc_config))
        file.close
        file
      end

      it "does not report transaction infromation in /newrelic" do
        newrelic_response = make_get_request("/newrelic", {}, port)
        expect(newrelic_response.code).to eq("404")
      end
    end
  end
end

