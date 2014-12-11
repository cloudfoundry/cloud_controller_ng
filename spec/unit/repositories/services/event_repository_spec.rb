require 'spec_helper'

module VCAP::CloudController
  module Repositories::Services
    describe EventRepository do
      let(:user) { VCAP::CloudController::User.make }
      let(:email) { 'email@example.com' }
      let(:security_context) { double(:security_context, current_user: user, current_user_email: email) }
      let(:logger) { double(:logger, error: nil) }
      let(:repository) { EventRepository.new(security_context, logger) }

      describe "record_service_plan_visibility_event" do
        let(:service_plan_visibility) { VCAP::CloudController::ServicePlanVisibility.make }

        it "creates the event" do
          repository.record_service_plan_visibility_event(:create, service_plan_visibility, {})

          event = Event.find(type: 'audit.service_plan_visibility.create')
          expect(event.actor_type).to eq('user')
          expect(event.timestamp).to be
          expect(event.actor).to eq(user.guid)
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(service_plan_visibility.guid)
          expect(event.actee_type).to eq('service_plan_visibility')
          expect(event.actee_name).to eq("")
          expect(event.space_guid).to be_empty
          expect(event.organization_guid).to eq(service_plan_visibility.organization.guid)
          expect(event.metadata).to eq({"service_plan_guid" => service_plan_visibility.service_plan.guid})
        end

        context "when it fails" do
          before do
            allow(Event).to receive(:create).and_raise
          end

          it "logs an error but does not propogate errors" do
            repository.record_service_plan_visibility_event(:create, service_plan_visibility, {})

            event = Event.find(type: 'audit.service_plan_visibility.create')
            expect(event).not_to be
            expect(logger).to have_received(:error)
          end
        end
      end

      describe '#record_broker_event' do
        let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
        let(:params) do
          {
            name: service_broker.name,
            broker_url: service_broker.broker_url,
            auth_username: service_broker.auth_username,
            auth_password: service_broker.auth_password,
          }
        end

        it 'creates an event' do
          repository.record_broker_event(:create, service_broker, params)

          event = Event.find(type: 'audit.service_broker.create')
          expect(event.actor_type).to eq('user')
          expect(event.timestamp).to be
          expect(event.actor).to eq(user.guid)
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(service_broker.guid)
          expect(event.actee_type).to eq('broker')
          expect(event.actee_name).to eq(service_broker.name)
          expect(event.space_guid).to be_empty
          expect(event.organization_guid).to be_empty
        end

        describe 'the metadata field' do
          it 'only includes param keys that have values' do
            repository.record_broker_event(:create, service_broker, { name: 'new-name'} )
            metadata = Event.first.metadata
            expect(metadata['request']).to include('name' => 'new-name')
            expect(metadata['request']).not_to have_key('broker_url')
            expect(metadata['request']).not_to have_key('auth_username')
            expect(metadata['request']).not_to have_key('auth_password')
          end

          it 'redacts the auth_password field' do
            repository.record_broker_event(:create, service_broker, { auth_password: 'new-passord'} )

            metadata = Event.first.metadata
            expect(metadata['request']).to include('auth_password' => '[REDACTED]')
          end

          context 'when no params are passed in' do
            it 'saves an empty hash' do
              repository.record_broker_event(:create, service_broker, {})

              expect(Event.first.metadata).to eq({})
            end
          end
        end

        context "when it fails" do
          before do
            allow(Event).to receive(:create).and_raise
          end

          it "logs an error but does not propogate errors" do
            repository.record_broker_event(:create, service_broker, {})

            event = Event.find(type: 'audit.service_broker.create')
            expect(event).not_to be
            expect(logger).to have_received(:error)
          end
        end
      end

      describe '#with_service_event' do
        let(:broker) { VCAP::CloudController::ServiceBroker.make }

        context 'when the service is new' do
          let(:service) do
            VCAP::CloudController::Service.new(
              service_broker: broker,
              label: 'name',
              description: 'some description',
              bindable: true,
              active: false,
              plan_updateable: false,
              unique_id: 'broker-provided-id',
            )
          end

          it 'records a create event' do
            repository.with_service_event(service) do
              service.save
            end

            event = VCAP::CloudController::Event.first(type: 'audit.service.create')
            expect(event.type).to eq('audit.service.create')
            expect(event.actor_type).to eq('service_broker')
            expect(event.actor).to eq(broker.guid)
            expect(event.actor_name).to eq(broker.name)
            expect(event.timestamp).to be
            expect(event.actee).to eq(service.guid)
            expect(event.actee_type).to eq('service')
            expect(event.actee_name).to eq(service.label)
            expect(event.space_guid).to eq('')
            expect(event.organization_guid).to eq('')
          end

          it 'records every field of the service in the metadata of the event' do
            repository.with_service_event(service) do
              service.save
            end

            event = Event.first(type: 'audit.service.create')
            expect(event.metadata).to include({
              'service_broker_guid' => service.service_broker.guid,
              'unique_id' => service.broker_provided_id,
              'provider' => service.provider,
              'url' => service.url,
              'version' => service.version,
              'info_url' => service.info_url,
              'bindable' => service.bindable,
              'long_description' => service.long_description,
              'documentation_url' => service.documentation_url,
              'label' => service.label,
              'description' => service.description,
              'tags' => service.tags,
              'extra' => service.extra,
              'active' => service.active,
              'requires' => service.requires,
              'plan_updateable' => service.plan_updateable,
            })
          end
        end

        context 'when the service already exists' do
          let!(:service) { Service.make(service_broker: broker, description: 'description') }
          before do
            service.plan_updateable = true
            service.extra = { 'extra' => 'data' }.to_json
            service.description = 'description' # field is updated but not changed
          end

          it 'creates an update event' do
            repository.with_service_event(service) do
              service.save
            end

            event = VCAP::CloudController::Event.first(type: 'audit.service.update')
            expect(event.type).to eq('audit.service.update')
            expect(event.actor_type).to eq('service_broker')
            expect(event.actor).to eq(broker.guid)
            expect(event.actor_name).to eq(broker.name)
            expect(event.timestamp).to be
            expect(event.actee).to eq(service.guid)
            expect(event.actee_type).to eq('service')
            expect(event.actee_name).to eq(service.label)
            expect(event.space_guid).to eq('')
            expect(event.organization_guid).to eq('')
          end

          it 'records in the metadata only those fields which were changed' do
            repository.with_service_event(service) do
              service.save
            end

            metadata = VCAP::CloudController::Event.first(type: 'audit.service.update').metadata
            expect(metadata.keys.length).to eq 2
            expect(metadata['plan_updateable']).to eq true
            expect(metadata['extra']).to eq({'extra' => 'data'}.to_json)
          end
        end
      end

      describe '#with_service_plan_event' do
        let(:broker) { VCAP::CloudController::ServiceBroker.make }
        let(:service) { VCAP::CloudController::Service.make(service_broker: broker) }

        context 'when the service is new' do
          let(:plan) do
            VCAP::CloudController::ServicePlan.new(
              service: service,
              name: 'myPlan',
              description: 'description',
              free: true,
              unique_id: 'broker-provided-id',
              active: false,
              public: false
            )
          end

          it 'records a create event' do
            repository.with_service_plan_event(plan) do
              plan.save
            end

            event = VCAP::CloudController::Event.first(type: 'audit.service_plan.create')
            expect(event.type).to eq('audit.service_plan.create')
            expect(event.actor_type).to eq('service_broker')
            expect(event.actor).to eq(broker.guid)
            expect(event.actor_name).to eq(broker.name)
            expect(event.timestamp).to be
            expect(event.actee).to eq(plan.guid)
            expect(event.actee_type).to eq('service_plan')
            expect(event.actee_name).to eq(plan.name)
            expect(event.space_guid).to eq('')
            expect(event.organization_guid).to eq('')
          end

          it 'records every field of the service plan in the metadata of the event' do
            repository.with_service_plan_event(plan) do
              plan.save
            end

            event = Event.first(type: 'audit.service_plan.create')
            expect(event.metadata).to include({
              'name' => plan.name,
              'description' => plan.description,
              'free' => plan.free,
              'active' => plan.active,
              'extra' => plan.extra,
              'unique_id' => plan.broker_provided_id,
              'public' => plan.public,
              'service_guid' => service.guid,
            })
          end
        end

        context 'when the service plan already exists' do
          let!(:plan) { ServicePlan.make(service: service, description: 'description') }
          before do
            plan.extra = { 'extra' => 'data' }.to_json
            plan.description = 'description'
          end

          it 'creates an update event' do
            repository.with_service_plan_event(plan) do
              plan.save
            end

            event = VCAP::CloudController::Event.first(type: 'audit.service_plan.update')
            expect(event.type).to eq('audit.service_plan.update')
            expect(event.actor_type).to eq('service_broker')
            expect(event.actor).to eq(broker.guid)
            expect(event.actor_name).to eq(broker.name)
            expect(event.timestamp).to be
            expect(event.actee).to eq(plan.guid)
            expect(event.actee_type).to eq('service_plan')
            expect(event.actee_name).to eq(plan.name)
            expect(event.space_guid).to eq('')
            expect(event.organization_guid).to eq('')
          end

          it 'records in the metadata only those fields which were changed' do
            repository.with_service_plan_event(plan) do
              plan.save
            end

            metadata = VCAP::CloudController::Event.first(type: 'audit.service_plan.update').metadata
            expect(metadata.keys.length).to eq 1
            expect(metadata['extra']).to eq({'extra' => 'data'}.to_json)
          end
        end
      end

      describe '#record_service_event' do
        let(:broker) { VCAP::CloudController::ServiceBroker.make }
        let(:service) { VCAP::CloudController::Service.make(service_broker: broker) }

        it 'creates an event with empty metadata because it is only used for delete events' do
          repository.record_service_event(:delete, service)

          event = Event.first
          expect(event.type).to eq('audit.service.delete')
          expect(event.actor_type).to eq('service_broker')
          expect(event.actor).to eq(broker.guid)
          expect(event.actor_name).to eq(broker.name)
          expect(event.timestamp).to be
          expect(event.actee).to eq(service.guid)
          expect(event.actee_type).to eq('service')
          expect(event.actee_name).to eq(service.label)
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.metadata).to eq({})
        end
      end

      describe '#record_service_plan_event' do
        let(:broker) { VCAP::CloudController::ServiceBroker.make }
        let(:service) { VCAP::CloudController::Service.make(service_broker: broker) }
        let(:plan) { VCAP::CloudController::ServicePlan.make(service: service) }

        it 'creates an event with empty metadata because it is only used for delete events' do
          repository.record_service_plan_event(:delete, plan)

          event = Event.first
          expect(event.type).to eq('audit.service_plan.delete')
          expect(event.actor_type).to eq('service_broker')
          expect(event.actor).to eq(broker.guid)
          expect(event.actor_name).to eq(broker.name)
          expect(event.timestamp).to be
          expect(event.actee).to eq(plan.guid)
          expect(event.actee_type).to eq('service_plan')
          expect(event.actee_name).to eq(plan.name)
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.metadata).to eq({})
        end
      end

      describe '#record_service_dashboard_client_event' do
        let(:broker) { VCAP::CloudController::ServiceBroker.make }
        let(:client_attrs) do
          {
            'id' => 'client-id',
            'secret' => 'super-secret',
            'redirect_uri' => 'redirect-here.com/thing'
          }
        end

        it 'creates an event' do
          repository.record_service_dashboard_client_event(:create, client_attrs, broker)

          event = VCAP::CloudController::Event.first(type: 'audit.service_dashboard_client.create', actee_name: client_attrs['id'])
          expect(event.actor_type).to eq('service_broker')
          expect(event.actor).to eq(broker.guid)
          expect(event.actor_name).to eq(broker.name)
          expect(event.timestamp).to be
          expect(event.actee).to eq(client_attrs['id'])
          expect(event.actee_type).to eq('service_dashboard_client')
          expect(event.actee_name).to eq(client_attrs['id'])
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.metadata['redirect_uri']).to eq client_attrs['redirect_uri']
        end

        it 'redacts the client secret' do
          repository.record_service_dashboard_client_event(:create, client_attrs, broker)

          event = VCAP::CloudController::Event.first(type: 'audit.service_dashboard_client.create', actee_name: client_attrs['id'])
          expect(event.metadata['secret']).to eq '[REDACTED]'
        end

        context 'when the redirect_uri is not updated' do
          let(:client_attrs) do
            {
              'id' => 'client-id',
              'secret' => 'super-secret',
            }
          end

          it 'leaves the metadata field empty' do
            repository.record_service_dashboard_client_event(:create, client_attrs, broker)

            event = VCAP::CloudController::Event.first(type: 'audit.service_dashboard_client.create', actee_name: client_attrs['id'])
            expect(event.metadata).to be_empty
          end
        end
      end

      describe '#record_service_instance_event' do
        let(:instance) { VCAP::CloudController::ServiceInstance.make }
        let(:params) do
          {
            'service_plan_guid' => 'plan-guid',
            'space-guid' => 'space-guid',
            'name' => 'instance-name'
          }
        end

        it 'records an event' do
          repository.record_service_instance_event(:create, instance, params)

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.create')
          expect(event.type).to eq('audit.service_instance.create')
          expect(event.actor_type).to eq('user')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_name).to eq(email)
          expect(event.timestamp).to be
          expect(event.actee).to eq(instance.guid)
          expect(event.actee_type).to eq('service_instance')
          expect(event.actee_name).to eq(instance.name)
          expect(event.space_guid).to eq(instance.space.guid)
          expect(event.space_id).to eq(instance.space.id)
          expect(event.organization_guid).to eq(instance.space.organization.guid)
        end

        it 'places the params in the metadata' do
          repository.record_service_instance_event(:create, instance, params)

          event = VCAP::CloudController::Event.first(type: 'audit.service_instance.create')
          expect(event.metadata).to eq({ 'request' => params })
        end
      end

      describe '#record_user_provided_service_instance_event' do
        let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make }
        let(:params) do
          {
            "name" => 'my-upsi',
            "space_guid" => instance.space.guid,
            "syslog_drain_url" => ""
          }
        end

        it 'records an event' do
          repository.record_user_provided_service_instance_event(:create, instance, params)
          event = Event.first(type: 'audit.user_provided_service_instance.create')

          expect(event.actor).to eq user.guid
          expect(event.actor_type).to eq 'user'
          expect(event.actor_name).to eq email
          expect(event.actee).to eq instance.guid
          expect(event.actee_type).to eq 'user_provided_service_instance'
          expect(event.actee_name).to eq instance.name
          expect(event.space_guid).to eq instance.space.guid
          expect(event.metadata).to eq('request' => params)
        end

        context 'when the params contain credentials' do
          let(:params) do
            {
              "name" => 'my-upsi',
              "credentials" => {
                'url' => 'user:password@url.com'
              },
              "space_guid" => instance.space.guid,
              "syslog_drain_url" => ""
            }
          end

          it 'redacts the credentials' do
            repository.record_user_provided_service_instance_event(:create, instance, params)
            event = Event.first(type: 'audit.user_provided_service_instance.create')
            expect(event.metadata).to eq('request' => {
              'name' => params['name'],
              'credentials' => '[REDACTED]',
              'space_guid' => params['space_guid'],
              'syslog_drain_url' => params['syslog_drain_url']
            })
          end
        end
      end

      describe '#record_service_binding_event' do
        let(:service_binding) { VCAP::CloudController::ServiceBinding.make }
        it 'records an event' do
          repository.record_service_binding_event(:create, service_binding)
          event = Event.first(type: 'audit.service_binding.create')
          metadata = {
            'request' => {
              'service_instance_guid' => service_binding.service_instance.guid,
              'app_guid' => service_binding.app.guid
            }
          }

          expect(event.actor).to eq user.guid
          expect(event.actor_type).to eq 'user'
          expect(event.actor_name).to eq email
          expect(event.actee).to eq service_binding.guid
          expect(event.actee_type).to eq 'service_binding'
          expect(event.actee_name).to eq ''
          expect(event.space_guid).to eq service_binding.space.guid
          expect(event.metadata).to eq(metadata)
        end
      end
    end
  end
end
