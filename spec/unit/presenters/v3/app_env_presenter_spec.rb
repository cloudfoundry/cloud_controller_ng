require 'spec_helper'
require 'presenters/v3/app_env_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppEnvPresenter do
    let(:app) do
      VCAP::CloudController::AppModel.make(
        created_at: Time.at(1),
        updated_at: Time.at(2),
        environment_variables: { 'some' => 'stuff' },
        desired_state: 'STOPPED',
      )
    end

    before do
      VCAP::CloudController::BuildpackLifecycleDataModel.create(
        buildpack: 'the-happiest-buildpack',
        stack: 'the-happiest-stack',
        app: app
      )
    end
    subject(:presenter) { AppEnvPresenter.new(app) }

    describe '#to_hash' do
      let(:service) { VCAP::CloudController::Service.make(label: 'rabbit', tags: ['swell']) }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: app.space, service_plan: service_plan, name: 'rabbit-instance') }
      let!(:service_binding) do
        VCAP::CloudController::ServiceBindingModel.create(app: app, service_instance: service_instance,
                                                          type: 'app', credentials: { 'url' => 'www.service.com/foo' }, syslog_drain_url: 'logs.go-here-2.com')
      end
      let(:result) { presenter.to_hash }

      it 'presents the app environment variables as json' do
        expect(result[:environment_variables]).to eq(app.environment_variables)
        expect(result[:application_env_json][:VCAP_APPLICATION][:name]).to eq(app.name)
        expect(result[:application_env_json][:VCAP_APPLICATION][:limits][:fds]).to eq(16384)
        expect(result[:system_env_json]).to have_key(:VCAP_SERVICES)
        expect(result[:staging_env_json]).to eq({})
        expect(result[:running_env_json]).to eq({})
      end
    end
  end
end
