require 'spec_helper'
require 'models/runtime/event'
require 'repositories/services/event_repository'
require 'cloud_controller/security_context'

module VCAP::Services::ServiceBrokers
  describe ServiceManager do
    let(:broker) { VCAP::CloudController::ServiceBroker.make }

    let(:service_id) { Sham.guid }
    let(:service_name) { Sham.name }
    let(:service_description) { Sham.description }
    let(:service_event_repository) do
      VCAP::CloudController::Repositories::Services::EventRepository.new(
        user: VCAP::CloudController::SecurityContext.current_user,
        user_email: VCAP::CloudController::SecurityContext.current_user_email,
      )
    end

    let(:plan_id) { Sham.guid }
    let(:plan_name) { Sham.name }
    let(:plan_description) { Sham.description }
    let(:service_metadata_hash) do
      { 'metadata' => { 'foo' => 'bar' } }
    end
    let(:plan_metadata_hash) do
      { 'metadata' => { 'cost' => '0.0' } }
    end
    let(:dashboard_client_attrs) do
      {
        'id' => 'abcde123',
        'secret' => 'sekret',
        'redirect_uri' => 'http://example.com'
      }
    end

    let(:catalog_hash) do
      {
        'services' => [
          {
            'id'          => service_id,
            'name'        => service_name,
            'description' => service_description,
            'bindable'    => true,
            'dashboard_client' => dashboard_client_attrs,
            'tags'        => ['mysql', 'relational'],
            'requires'    => ['ultimate', 'power'],
            'plan_updateable' => true,
            'plans' => [
              {
                'id'          => plan_id,
                'name'        => plan_name,
                'description' => plan_description,
                'free'        => false,
              }.merge(plan_metadata_hash)
            ]
          }.merge(service_metadata_hash)
        ]
      }
    end

    let(:catalog) { V2::Catalog.new(broker, catalog_hash) }
    let(:service_manager) { ServiceManager.new(service_event_repository) }

    let(:user_email) { 'user@example.com' }
    let(:token) do
      {
        'scope' => ['cloud_controller.read', 'cloud_controller.write'],
        'email' => user_email,
      }
    end
    let(:user) { VCAP::CloudController::User.make }

    before do
      VCAP::CloudController::SecurityContext.set(user, token)
    end
    after do
      VCAP::CloudController::SecurityContext.clear
    end

    describe 'initializing' do
      subject { described_class.new(service_event_repository) }

      its(:has_warnings?) { should eq false }
      its(:warnings) { should eq [] }
    end

    describe '#sync_services_and_plans' do
      it 'creates services from the catalog' do
        expect {
          service_manager.sync_services_and_plans(catalog)
        }.to change(VCAP::CloudController::Service, :count).by(1)

        service = VCAP::CloudController::Service.last
        expect(service.service_broker).to eq(broker)
        expect(service.label).to eq(service_name)
        expect(service.description).to eq(service_description)
        expect(service.bindable).to be true
        expect(service.tags).to match_array(['mysql', 'relational'])
        expect(JSON.parse(service.extra)).to eq({ 'foo' => 'bar' })
        expect(service.requires).to eq(['ultimate', 'power'])
        expect(service.plan_updateable).to eq true
      end

      it 'records an audit event for each service and plan' do
        service_manager.sync_services_and_plans(catalog)

        event = VCAP::CloudController::Event.first(type: 'audit.service.create')
        service = VCAP::CloudController::Service.last
        expect(event.type).to eq('audit.service.create')
        expect(event.actor_type).to eq('service_broker')
        expect(event.actor).to eq(broker.guid)
        expect(event.actor_name).to eq(broker.name)
        expect(event.timestamp).to be
        expect(event.actee).to eq(service.guid)
        expect(event.actee_type).to eq('service')
        expect(event.actee_name).to eq(service_name)
        expect(event.space_guid).to eq('')
        expect(event.organization_guid).to eq('')
        expect(event.metadata).to include({
          'service_broker_guid' => service.service_broker.guid,
          'unique_id' => service_id,
          'provider' => service.provider,
          'url' => service.url,
          'version' => service.version,
          'info_url' => service.info_url,
          'bindable' => service.bindable,
          'long_description' => service.long_description,
          'documentation_url' => service.documentation_url,
          'label' => service_name,
          'description' => service.description,
          'tags' => service.tags,
          'extra' => service.extra,
          'active' => service.active,
          'requires' => service.requires,
          'plan_updateable' => service.plan_updateable,
        })

        event = VCAP::CloudController::Event.first(type: 'audit.service_plan.create')
        service_plan = VCAP::CloudController::ServicePlan.last
        expect(event.type).to eq('audit.service_plan.create')
        expect(event.actor_type).to eq('service_broker')
        expect(event.actor).to eq(broker.guid)
        expect(event.actor_name).to eq(broker.name)
        expect(event.timestamp).to be
        expect(event.actee).to eq(service_plan.guid)
        expect(event.actee_type).to eq('service_plan')
        expect(event.actee_name).to eq(plan_name)
        expect(event.space_guid).to eq('')
        expect(event.organization_guid).to eq('')
        expect(event.metadata).to include({
          'name' => service_plan.name,
          'free' => service_plan.free,
          'description' => service_plan.description,
          'service_guid' => service_plan.service.guid,
          'extra' => '{"cost":"0.0"}',
          'unique_id' => service_plan.unique_id,
          'public' => service_plan.public,
          'active' => service_plan.active
        })
      end

      context 'when catalog service metadata is nil' do
        let(:service_metadata_hash) { { 'metadata' => nil } }

        it 'leaves the extra field as nil' do
          service_manager.sync_services_and_plans(catalog)
          service = VCAP::CloudController::Service.last
          expect(service.extra).to be_nil
        end
      end

      context 'when the catalog service has no metadata key' do
        let(:service_metadata_hash) { {} }

        it 'leaves the extra field as nil' do
          service_manager.sync_services_and_plans(catalog)
          service = VCAP::CloudController::Service.last
          expect(service.extra).to be_nil
        end
      end

      context 'when the plan does not exist in the database' do
        it 'creates plans from the catalog' do
          expect {
            service_manager.sync_services_and_plans(catalog)
          }.to change(VCAP::CloudController::ServicePlan, :count).by(1)

          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.service).to eq(VCAP::CloudController::Service.last)
          expect(plan.name).to eq(plan_name)
          expect(plan.description).to eq(plan_description)
          expect(JSON.parse(plan.extra)).to eq({ 'cost' => '0.0' })

          expect(plan.free).to be false
        end

        it 'marks the plan as private' do
          service_manager.sync_services_and_plans(catalog)
          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.public).to be false
        end
      end

      context 'when the catalog service plan metadata is empty' do
        let(:plan_metadata_hash) { { 'metadata' => nil } }

        it 'leaves the plan extra field as nil' do
          service_manager.sync_services_and_plans(catalog)
          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.extra).to be_nil
        end
      end

      context 'when the catalog service plan has no metadata key' do
        let(:plan_metadata_hash) { {} }

        it 'leaves the plan extra field as nil' do
          service_manager.sync_services_and_plans(catalog)
          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.extra).to be_nil
        end
      end

      context 'when a service already exists' do
        let!(:service) do
          VCAP::CloudController::Service.make(
            service_broker: broker,
            unique_id: service_id
          )
        end

        it 'updates the existing service' do
          expect(service.label).to_not eq(service_name)
          expect(service.description).to_not eq(service_description)

          expect {
            service_manager.sync_services_and_plans(catalog)
          }.to_not change(VCAP::CloudController::Service, :count)

          service.reload
          expect(service.label).to eq(service_name)
          expect(service.description).to eq(service_description)
        end

        context 'when the broker is different' do
          let(:different_broker) { VCAP::CloudController::ServiceBroker.make }
          let!(:service) do
            VCAP::CloudController::Service.make(
              service_broker: different_broker,
              unique_id: service_id
            )
          end

          it 'raises a database error' do
            expect {
              service_manager.sync_services_and_plans(catalog)
            }.to raise_error Sequel::ValidationFailed
          end
        end

        it 'creates the new plan' do
          expect {
            service_manager.sync_services_and_plans(catalog)
          }.to change(VCAP::CloudController::ServicePlan, :count).by(1)

          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.service).to eq(VCAP::CloudController::Service.last)
          expect(plan.name).to eq(plan_name)
          expect(plan.description).to eq(plan_description)

          expect(plan.free).to be false
        end

        context 'and a plan already exists' do
          let!(:plan) do
            VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: plan_id,
              free: true
            )
          end

          it 'updates the existing plan' do
            expect(plan.name).to_not eq(plan_name)
            expect(plan.description).to_not eq(plan_description)
            expect(plan.free).to be true

            expect {
              service_manager.sync_services_and_plans(catalog)
            }.to_not change(VCAP::CloudController::ServicePlan, :count)

            plan.reload
            expect(plan.name).to eq(plan_name)
            expect(plan.description).to eq(plan_description)
            expect(plan.free).to be false
          end

          context 'when the plan is public' do
            before do
              plan.update(public: true)
            end

            it 'does not make it public' do
              service_manager.sync_services_and_plans(catalog)
              plan.reload
              expect(plan.public).to be true
            end
          end
        end

        context 'and a plan exists that has been removed from the broker catalog' do
          let(:missing_plan_name) { '111' }
          let!(:missing_plan) do
            VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: 'nolongerexists',
              name: missing_plan_name,
            )
          end

          it 'deletes the plan from the db' do
            service_manager.sync_services_and_plans(catalog)
            expect(VCAP::CloudController::ServicePlan.find(id: missing_plan.id)).to be_nil
          end

          it 'creates service audit events for each service plan deleted' do
            service_manager.sync_services_and_plans(catalog)

            event = VCAP::CloudController::Event.first(type: 'audit.service_plan.delete')
            expect(event.type).to eq('audit.service_plan.delete')
            expect(event.actor_type).to eq('service_broker')
            expect(event.actor).to eq(broker.guid)
            expect(event.actor_name).to eq(broker.name)
            expect(event.timestamp).to be
            expect(event.actee).to eq(missing_plan.guid)
            expect(event.actee_type).to eq('service_plan')
            expect(event.actee_name).to eq(missing_plan.name)
            expect(event.space_guid).to eq('')
            expect(event.organization_guid).to eq('')
            expect(event.metadata).to be_empty
          end

          context 'when an instance for the plan exists' do
            let(:service_name) { 'AAA' }
            let(:missing_plan2_name) { '222' }
            let(:missing_service2_name) { 'BBB' }
            let(:missing_service2_plan_name) { '111-B' }

            before do
              VCAP::CloudController::ManagedServiceInstance.make(service_plan: missing_plan)

              missing_plan2 = VCAP::CloudController::ServicePlan.make(service: service, unique_id: 'plan2_nolongerexists', name: missing_plan2_name)
              VCAP::CloudController::ManagedServiceInstance.make(service_plan: missing_plan2)
            end

            it 'marks the existing plan as inactive' do
              expect(missing_plan).to be_active

              service_manager.sync_services_and_plans(catalog)
              missing_plan.reload

              expect(missing_plan).not_to be_active
            end

            context 'when there are existing service instances' do
              before do
                missing_service2 = VCAP::CloudController::Service.make(service_broker: broker, label: missing_service2_name)
                missing_service2_plan = VCAP::CloudController::ServicePlan.make(service: missing_service2, unique_id: 'i_be_gone', name: missing_service2_plan_name)
                VCAP::CloudController::ManagedServiceInstance.make(service_plan: missing_service2_plan)
              end

              it 'adds a formatted warning' do
                service_manager.sync_services_and_plans(catalog)
                expect(service_manager.warnings).to include(<<HEREDOC)
Warning: Service plans are missing from the broker's catalog (#{broker.broker_url}/v2/catalog) but can not be removed from Cloud Foundry while instances exist. The plans have been deactivated to prevent users from attempting to provision new instances of these plans. The broker should continue to support bind, unbind, and delete for existing instances; if these operations fail contact your broker provider.
#{service_name}
  #{missing_plan_name}
  #{missing_plan2_name}
#{missing_service2_name}
  #{missing_service2_plan_name}
HEREDOC
              end
            end

            context 'when there are no existing service instances' do
              it 'does not add a formatted warning' do
                service_manager.sync_services_and_plans(catalog)
                expect(service_manager.warnings).to_not include(<<HEREDOC)
Warning: Service plans are missing from the broker's catalog (#{broker.broker_url}/v2/catalog) but can not be removed from Cloud Foundry while instances exist. The plans have been deactivated to prevent users from attempting to provision new instances of these plans. The broker should continue to support bind, unbind, and delete for existing instances; if these operations fail contact your broker provider.
#{service_name}
  #{missing_plan_name}
  #{missing_plan2_name}
#{missing_service2_name}
  #{missing_service2_plan_name}
HEREDOC
              end
            end
          end
        end
      end

      context 'when a service no longer exists' do
        let!(:service) do
          VCAP::CloudController::Service.make(
            service_broker: broker,
            unique_id: 'nolongerexists',
            label: 'was-an-awesome-service',
          )
        end

        let!(:service_owned_by_other_broker) do
          other_service_broker = VCAP::CloudController::ServiceBroker.make

          VCAP::CloudController::Service.make(
            service_broker: other_service_broker,
            unique_id: 'other-service-id'
          )
        end

        it 'should delete the service' do
          service_manager.sync_services_and_plans(catalog)
          expect(VCAP::CloudController::Service.find(id: service.id)).to be_nil
        end

        it 'creates service audit events for each service deleted' do
          service_manager.sync_services_and_plans(catalog)

          event = VCAP::CloudController::Event.first(type: 'audit.service.delete')
          expect(event.type).to eq('audit.service.delete')
          expect(event.actor_type).to eq('service_broker')
          expect(event.actor).to eq(broker.guid)
          expect(event.actor_name).to eq(broker.name)
          expect(event.timestamp).to be
          expect(event.actee).to eq(service.guid)
          expect(event.actee_type).to eq('service')
          expect(event.actee_name).to eq('was-an-awesome-service')
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.metadata).to be_empty
        end

        it 'should not delete services owned by other brokers' do
          service_manager.sync_services_and_plans(catalog)
          expect(VCAP::CloudController::Service.find(id: service_owned_by_other_broker.id)).not_to be_nil
        end

        context 'but it has an active plan' do
          before do
            plan = VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: 'also_no_longer_in_catalog'
            )
            VCAP::CloudController::ManagedServiceInstance.make(service_plan: plan)

            other_broker_plan = VCAP::CloudController::ServicePlan.make(
              service: service_owned_by_other_broker,
              unique_id: 'in-another-brokers-catalog'
            )
            VCAP::CloudController::ManagedServiceInstance.make(service_plan: other_broker_plan)
          end

          it 'marks the existing service as inactive' do
            expect(service).to be_active

            service_manager.sync_services_and_plans(catalog)
            service.reload

            expect(service).not_to be_active
          end

          it 'does not mark a service belonging to another broker as inactive' do
            expect(service_owned_by_other_broker).to be_active

            service_manager.sync_services_and_plans(catalog)
            service_owned_by_other_broker.reload

            expect(service_owned_by_other_broker).to be_active
          end
        end
      end
    end

    describe '#has_warnings?' do
      context 'when there are no warnings' do
        before do
          allow(service_manager).to receive(:warnings).and_return([])
        end

        it 'returns false' do
          expect(service_manager.has_warnings?).to be false
        end
      end

      context 'when there are warnings' do
        before do
          allow(service_manager).to receive(:warnings).and_return(['a warning'])
        end

        it 'returns true' do
          expect(service_manager.has_warnings?).to be true
        end
      end
    end
  end
end
