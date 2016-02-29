require 'spec_helper'

module VCAP::CloudController
  describe SystemEnvPresenter do
    subject(:system_env_presenter) { SystemEnvPresenter.new(app.all_service_bindings) }

    describe '#system_env' do
      context 'when there are no services' do
        let(:app) { App.make(environment_json: { 'jesse' => 'awesome' }) }

        it 'contains an empty vcap_services' do
          expect(system_env_presenter.system_env[:VCAP_SERVICES]).to eq({})
        end
      end

      context 'when there are services' do
        let(:space) { Space.make }
        let(:app) { App.make(environment_json: { 'jesse' => 'awesome' }, space: space) }
        let(:service) { Service.make(label: 'elephantsql-n/a', provider: 'cool-provider') }
        let(:service_alt) { Service.make(label: 'giraffesql-n/a') }
        let(:service_plan) { ServicePlan.make(service: service) }
        let(:service_plan_alt) { ServicePlan.make(service: service_alt) }
        let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan, name: 'elephantsql-vip-uat', tags: ['excellent']) }
        let(:service_instance_same_label) { ManagedServiceInstance.make(space: space, service_plan: service_plan, name: 'elephantsql-2') }
        let(:service_instance_diff_label) { ManagedServiceInstance.make(space: space, service_plan: service_plan_alt, name: 'giraffesql-vip-uat') }
        let!(:service_binding) { ServiceBinding.make(app: app, service_instance: service_instance, syslog_drain_url: 'logs.go-here.com') }

        it 'contains a populated vcap_services' do
          expect(system_env_presenter.system_env[:VCAP_SERVICES]).not_to eq({})
          expect(system_env_presenter.system_env[:VCAP_SERVICES]).to have_key(service.label)
          expect(system_env_presenter.system_env[:VCAP_SERVICES][service.label]).to have(1).services
        end

        it 'includes service binding information' do
          expect(system_env_presenter.system_env[:VCAP_SERVICES][service.label]).to have(1).items
          expect(system_env_presenter.system_env[:VCAP_SERVICES][service.label].first).to eq(
            credentials: service_binding.credentials,
            syslog_drain_url: 'logs.go-here.com',
            label: 'elephantsql-n/a',
            provider: 'cool-provider',
            plan: service_plan.name,
            name: 'elephantsql-vip-uat',
            tags: ['excellent']
            )
        end

        context 'when the service is user-provided' do
          let(:service_instance) { UserProvidedServiceInstance.make(space: space, name: 'elephantsql-vip-uat') }

          it 'includes service binding information' do
            expect(system_env_presenter.system_env[:VCAP_SERVICES]['user-provided']).to have(1).items
            expect(system_env_presenter.system_env[:VCAP_SERVICES]['user-provided'].first).to eq(
              credentials: service_binding.credentials,
              syslog_drain_url: 'logs.go-here.com',
              label: 'user-provided',
              name: 'elephantsql-vip-uat',
              tags: []
              )
          end
        end

        context 'when process belongs to a parent(v3) app bound to a service' do
          let(:parent_app) { AppModel.make space_guid: space.guid }
          let(:service) { Service.make(label: 'rabbit', tags: ['swell']) }
          let(:service_plan) { ServicePlan.make(service: service) }
          let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan, name: 'rabbit-instance') }
          let!(:service_binding) do
            ServiceBindingModel.create(app: parent_app, service_instance: service_instance,
                                       type: 'app', credentials: { 'url' => 'www.service.com/foo' }, syslog_drain_url: 'logs.go-here-2.com')
          end

          before do
            app.app = parent_app
          end

          it 'includes the services from the parent' do
            expect(system_env_presenter.system_env[:VCAP_SERVICES]).not_to eq({})
            expect(system_env_presenter.system_env[:VCAP_SERVICES]).to have_key(service.label)
          end

          it 'includes service binding information' do
            binding_information = system_env_presenter.system_env[:VCAP_SERVICES]['rabbit'].first
            expect(binding_information).to eq(
              credentials: service_binding.credentials,
              syslog_drain_url: service_binding.syslog_drain_url,
              label: service.label,
              provider: service.provider,
              plan: service_plan.name,
              name: service_instance.name,
              tags: service_instance.merged_tags
              )
          end
        end

        describe 'grouping' do
          before do
            ServiceBinding.make(app: app, service_instance: service_instance_same_label)
            ServiceBinding.make(app: app, service_instance: service_instance_diff_label)
          end

          it 'should group services by label' do
            expect(system_env_presenter.system_env[:VCAP_SERVICES]).to have(2).groups
            expect(system_env_presenter.system_env[:VCAP_SERVICES][service.label]).to have(2).services
            expect(system_env_presenter.system_env[:VCAP_SERVICES][service_alt.label]).to have(1).service
          end
        end
      end
    end
  end
end
