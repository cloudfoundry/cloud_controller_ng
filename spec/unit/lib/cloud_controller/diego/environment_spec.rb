require 'spec_helper'

module VCAP::CloudController::Diego
  describe Environment do
    let(:app) do
      app = VCAP::CloudController::AppFactory.make
      app.environment_json = {
        APP_KEY1: 'APP_VAL1',
        APP_KEY2: { nested: 'data' },
        APP_KEY3: [1, 2, 3],
        APP_KEY4: 1,
        APP_KEY5: true,
      }
      app
    end

    it 'returns the correct environment hash for an application' do
      vcap_app = app.vcap_application
      Environment::EXCLUDE.each { |k| vcap_app.delete(k) }
      encoded_vcap_application_json = vcap_app.to_json

      encoded_vcap_services_json = app.system_env_json['VCAP_SERVICES'].to_json

      expect(Environment.new(app).as_json).to eq([
        { 'name' => 'VCAP_APPLICATION', 'value' => encoded_vcap_application_json },
        { 'name' => 'VCAP_SERVICES', 'value' => encoded_vcap_services_json },
        { 'name' => 'MEMORY_LIMIT', 'value' => "#{app.memory}m" },
        { 'name' => 'CF_STACK', 'value' => "#{app.stack.name}" },
        { 'name' => 'APP_KEY1', 'value' => 'APP_VAL1' },
        { 'name' => 'APP_KEY2', 'value' => '{"nested":"data"}' },
        { 'name' => 'APP_KEY3', 'value' => '[1,2,3]' },
        { 'name' => 'APP_KEY4', 'value' => '1' },
        { 'name' => 'APP_KEY5', 'value' => 'true' },
      ])
    end

    context 'when an initial environment is provided' do
      it 'is added first' do
        initial_env = { 'a' => 'b', 'last' => 'one' }
        expect(Environment.new(app, initial_env).as_json.slice(0..1)).to eq([
          { 'name' => 'a', 'value' => 'b' },
          { 'name' => 'last', 'value' => 'one' },
        ])
      end
    end

    context 'when the app has a database_uri' do
      before do
        allow(app).to receive(:database_uri).and_return('fake-database-uri')
      end
      it 'includes DATABASE_URL' do
        expect(Environment.new(app).as_json).to include('name' => 'DATABASE_URL', 'value' => 'fake-database-uri')
      end
    end
  end
end
