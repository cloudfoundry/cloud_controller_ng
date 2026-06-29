require 'spec_helper'
require 'presenters/v3/app_env_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppEnvPresenter do
    let(:app) do
      create(:app_model, created_at: Time.at(1),
                         updated_at: Time.at(2),
                         environment_variables: { 'some' => 'stuff' },
                         desired_state: 'STOPPED')
    end
    let(:buildpack_name) { 'the-happiest-buildpack' }

    before do
      create(:buildpack, name: buildpack_name)
      VCAP::CloudController::BuildpackLifecycleDataModel.create(
        buildpacks: [buildpack_name],
        stack: 'the-happiest-stack',
        app: app
      )
    end

    let(:show_secrets) { true }

    subject(:presenter) { AppEnvPresenter.new(app, show_secrets) }

    describe '#to_hash' do
      let(:service) { create(:service, label: 'rabbit', tags: ['swell']) }
      let(:service_plan) { create(:service_plan, service:) }
      let(:service_instance) { create(:managed_service_instance, space: app.space, service_plan: service_plan, name: 'rabbit-instance') }
      let!(:service_binding) do
        VCAP::CloudController::ServiceBinding.create(app: app, service_instance: service_instance,
                                                     type: 'app', credentials: { 'url' => 'www.service.com/foo' }, syslog_drain_url: 'logs.go-here-2.com')
      end
      let(:result) { presenter.to_hash }

      it 'presents the app environment variables as json' do
        expect(result[:environment_variables]).to eq(app.environment_variables)
        expect(result[:application_env_json][:VCAP_APPLICATION][:name]).to eq(app.name)
        expect(result[:application_env_json][:VCAP_APPLICATION][:limits][:fds]).to eq(16_384)
        expect(result[:system_env_json]).to have_key(:VCAP_SERVICES)
        expect(result[:staging_env_json]).to eq({})
        expect(result[:running_env_json]).to eq({})
      end

      describe 'with show secrets false' do
        let(:show_secrets) { false }

        it 'redacts system env json' do
          expect(result[:system_env_json]['redacted_message']).to eq('[PRIVATE DATA HIDDEN]')
        end
      end
    end
  end
end
