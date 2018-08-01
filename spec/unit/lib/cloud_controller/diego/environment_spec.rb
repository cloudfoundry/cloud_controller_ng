require 'spec_helper'
require 'presenters/system_env_presenter'
require_relative '../../../../../lib/vcap/vars_builder'

module VCAP::CloudController::Diego
  RSpec.describe Environment do
    let(:process) { VCAP::CloudController::AppFactory.make(environment_json: environment) }
    let!(:binding) { VCAP::CloudController::ServiceBinding.make(app: process.app, service_instance: VCAP::CloudController::ManagedServiceInstance.make(space: process.space)) }
    let(:environment) do
      {
        APP_KEY1: 'APP_VAL1',
        APP_KEY2: { nested: 'data' },
        APP_KEY3: [1, 2, 3],
        APP_KEY4: 1,
        APP_KEY5: true,
      }
    end

    it 'returns the correct environment hash for an application' do
      vcap_app = VCAP::VarsBuilder.new(process).to_hash

      Environment::EXCLUDE.each { |k| vcap_app.delete(k) }
      encoded_vcap_application_json = vcap_app.to_json

      vcap_services_key = :VCAP_SERVICES
      system_env = SystemEnvPresenter.new(process.service_bindings).system_env
      expect(system_env).to have_key(vcap_services_key)

      encoded_vcap_services_json = system_env[vcap_services_key].to_json
      expect(Environment.new(process).as_json).to eq([
        { 'name' => 'VCAP_APPLICATION', 'value' => encoded_vcap_application_json },
        { 'name' => 'MEMORY_LIMIT', 'value' => "#{process.memory}m" },
        { 'name' => 'VCAP_SERVICES', 'value' => encoded_vcap_services_json },
        { 'name' => 'APP_KEY1', 'value' => 'APP_VAL1' },
        { 'name' => 'APP_KEY2', 'value' => '{"nested":"data"}' },
        { 'name' => 'APP_KEY3', 'value' => '[1,2,3]' },
        { 'name' => 'APP_KEY4', 'value' => '1' },
        { 'name' => 'APP_KEY5', 'value' => 'true' },
      ])
    end

    context 'when an initial environment is provided' do
      initial_env = { 'a' => 'b', 'last' => 'one' }

      it 'is added first' do
        expect(Environment.new(process, initial_env).as_json.slice(0..1)).to eq([
          { 'name' => 'a', 'value' => 'b' },
          { 'name' => 'last', 'value' => 'one' },
        ])
      end
    end

    context 'when the app has a database_uri' do
      before do
        allow(process).to receive(:database_uri).and_return('fake-database-uri')
      end
      it 'includes DATABASE_URL' do
        expect(Environment.new(process).as_json).to include('name' => 'DATABASE_URL', 'value' => 'fake-database-uri')
      end
    end
  end
end
