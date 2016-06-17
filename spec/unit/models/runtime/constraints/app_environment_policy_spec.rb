require 'spec_helper'

RSpec.describe AppEnvironmentPolicy do
  describe 'env' do
    let(:app) { VCAP::CloudController::AppFactory.make }

    subject(:validator) { AppEnvironmentPolicy.new(app) }

    it 'allows an empty environment' do
      app.environment_json = {}
      expect(validator).to validate_without_error(app)
    end

    it 'does allow an array' do
      app.environment_json = []
      expect(validator).to validate_with_error(app, :environment_json, :invalid_environment)
    end

    it 'allows multiple variables' do
      app.environment_json = { abc: 123, def: 'hi' }
      expect(validator).to validate_without_error(app)
    end

    ['VMC', 'vmc', 'VCAP', 'vcap'].each do |env_var_name|
      it "does not allow entries to start with #{env_var_name}" do
        app.environment_json = { :abc => 123, "#{env_var_name}_abc" => 'hi' }
        expect(validator).to validate_with_error(app, :environment_json, AppEnvironmentPolicy::RESERVED_ENV_VAR_ERROR_MSG % "#{env_var_name}_abc")
      end
    end
  end
end
