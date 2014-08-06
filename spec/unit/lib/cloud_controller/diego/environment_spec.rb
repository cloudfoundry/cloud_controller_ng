require "spec_helper"

module VCAP::CloudController::Diego
  describe Environment do
    let(:app) do
      app = VCAP::CloudController::AppFactory.make
      app.environment_json = {APP_KEY: "APP_VAL"}
      app
    end

    it "returns the correct environment hash for an application" do
      expected_environment = [
        {name: "VCAP_APPLICATION", value: app.vcap_application.to_json},
        {name: "VCAP_SERVICES", value: app.system_env_json["VCAP_SERVICES"].to_json},
        {name: "MEMORY_LIMIT", value: "#{app.memory}m"},
        {name: "APP_KEY", value: "APP_VAL"},
      ]

      expect(Environment.new(app).to_a).to match_object(expected_environment)
    end
  end
end
