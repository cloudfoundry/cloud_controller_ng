require 'spec_helper'
require 'presenters/system_environment/system_env_presenter'
require_relative '../../../../../lib/vcap/vars_builder'

module VCAP::CloudController::Diego
  RSpec.describe Environment do
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(environment_json: environment, memory: 200) }
    let!(:binding) { VCAP::CloudController::ServiceBinding.make(app: process.app, service_instance: VCAP::CloudController::ManagedServiceInstance.make(space: process.space)) }
    let(:environment) do
      {
        'APP_KEY1' => 'APP_VAL1',
        'APP_KEY2' => { 'nested' => 'data' },
        'APP_KEY3' => [1, 2, 3],
        'APP_KEY4' => 1,
        'APP_KEY5' => true
      }
    end

    it 'returns the correct environment hash for an application' do
      vcap_app = VCAP::VarsBuilder.new(process, memory_limit: 200).to_hash

      Environment::EXCLUDE.each { |k| vcap_app.delete(k) }
      encoded_vcap_application_json = vcap_app.to_json

      vcap_services_key = :VCAP_SERVICES
      system_env = SystemEnvPresenter.new(process).system_env
      expect(system_env).to have_key(vcap_services_key)

      encoded_vcap_services_json = system_env[vcap_services_key].to_json
      expect(Environment.new(process).as_json).to eq([
        { 'name' => 'APP_KEY1', 'value' => 'APP_VAL1' },
        { 'name' => 'APP_KEY2', 'value' => '{"nested":"data"}' },
        { 'name' => 'APP_KEY3', 'value' => '[1,2,3]' },
        { 'name' => 'APP_KEY4', 'value' => '1' },
        { 'name' => 'APP_KEY5', 'value' => 'true' },
        { 'name' => 'VCAP_APPLICATION', 'value' => encoded_vcap_application_json },
        { 'name' => 'MEMORY_LIMIT', 'value' => '200m' },
        { 'name' => 'VCAP_SERVICES', 'value' => encoded_vcap_services_json }
      ])
    end

    context 'when the user specifies their own MEMORY_LIMIT' do
      it 'uses the system provided MEMORY_LIMIT' do
        environment['MEMORY_LIMIT'] = 'i-should-not-be-usedMB'

        expect(Environment.new(process).as_json).
          to include({ 'name' => 'MEMORY_LIMIT', 'value' => "#{process.memory}m" })
      end
    end

    context 'when an initial environment is provided' do
      initial_env = { 'a' => 'b', 'last' => 'one' }

      it 'is added first' do
        expect(Environment.new(process, initial_env).as_json.slice(0..1)).to eq([
          { 'name' => 'a', 'value' => 'b' },
          { 'name' => 'last', 'value' => 'one' }
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

    context 'when the process has sidecars' do
      let!(:sidecar0) { VCAP::CloudController::SidecarModel.make(app: process.app, name: 'my_sidecar1', command: 'athenz', memory: 10) }
      let!(:sidecar1) { VCAP::CloudController::SidecarModel.make(app: process.app, name: 'my_sidecar2', command: 'newrelic', memory: 20) }
      let!(:sidecar_process_type0) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar0, type: 'web') }
      let!(:sidecar_process_type1) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1, type: 'web') }

      it 'can produce environment variables for those sidecars' do
        expect(Environment.new(process).as_json_for_sidecar(sidecar0)).
          to include({ 'name' => 'MEMORY_LIMIT', 'value' => '10m' })
        expect(Environment.new(process).as_json_for_sidecar(sidecar1)).
          to include({ 'name' => 'MEMORY_LIMIT', 'value' => '20m' })

        sidecar0_vcap_application_json = Environment.new(process).as_json_for_sidecar(sidecar0).find { |e| e['name'] == 'VCAP_APPLICATION' }['value']
        expect(Oj.load(sidecar0_vcap_application_json)['limits']['mem']).to eq(10)

        sidecar1_vcap_application_json = Environment.new(process).as_json_for_sidecar(sidecar1).find { |e| e['name'] == 'VCAP_APPLICATION' }['value']
        expect(Oj.load(sidecar1_vcap_application_json)['limits']['mem']).to eq(20)
      end

      it 'subtracts sidecar memory limits from the main actions environment variables' do
        expect(Environment.new(process).as_json).
          to include({ 'name' => 'MEMORY_LIMIT', 'value' => '170m' })

        vcap_application_json = Environment.new(process).as_json.find { |e| e['name'] == 'VCAP_APPLICATION' }['value']
        expect(Oj.load(vcap_application_json)['limits']['mem']).to eq(170)
      end

      context 'when a sidecar doesnt have a memory limit' do
        let!(:unconstrained_sidecar) do
          VCAP::CloudController::SidecarModel.make(
            app: process.app,
            name: 'unconstrained',
            command: 'consul_agent',
            memory: nil
          )
        end

        it 'sidecar env vars inherit the main actions limit' do
          expect(Environment.new(process).as_json_for_sidecar(unconstrained_sidecar)).
            to include({ 'name' => 'MEMORY_LIMIT', 'value' => '200m' })
        end

        it 'does not subtract its limit from the main actions environment variables' do
          expect(Environment.new(process).as_json).
            to include({ 'name' => 'MEMORY_LIMIT', 'value' => '170m' })
        end

        it 'but the other sidecars still get their own subtractive limits' do
          expect(Environment.new(process).as_json_for_sidecar(sidecar0)).
            to include({ 'name' => 'MEMORY_LIMIT', 'value' => '10m' })
          expect(Environment.new(process).as_json_for_sidecar(sidecar1)).
            to include({ 'name' => 'MEMORY_LIMIT', 'value' => '20m' })
        end
      end
    end
  end
end
