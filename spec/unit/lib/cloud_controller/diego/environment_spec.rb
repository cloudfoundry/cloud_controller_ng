require "spec_helper"

module VCAP::CloudController::Diego
  describe Environment do
    let(:app) do
      app = VCAP::CloudController::AppFactory.make
      app.environment_json = {
        APP_KEY1: "APP_VAL1",
        APP_KEY2: "APP_VAL2",
      }
      app
    end

    it "returns the correct environment hash for an application" do
      encoded_vcap_application_json = app.vcap_application.to_json
      encoded_vcap_services_json = app.system_env_json["VCAP_SERVICES"].to_json

      expect(Environment.new(app).as_json).to eq([
        {"name" => "VCAP_APPLICATION", "value" => encoded_vcap_application_json},
        {"name" => "VCAP_SERVICES", "value" => encoded_vcap_services_json},
        {"name" => "MEMORY_LIMIT", "value" => "#{app.memory}m"},
        {"name" => "APP_KEY1", "value" => "APP_VAL1"},
        {"name" => "APP_KEY2", "value" => "APP_VAL2"},
      ])
    end

    context "when the app has a database_uri" do
      before do
        allow(app).to receive(:database_uri).and_return("fake-database-uri")
      end
      it "includes DATABASE_URL" do
        expect(Environment.new(app).as_json).to include("name" => "DATABASE_URL", "value" => "fake-database-uri")
      end
    end
  end
end
