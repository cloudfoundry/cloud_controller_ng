require 'spec_helper'

require 'models/services/service_broker/v2/catalog'

module VCAP::CloudController::ServiceBroker::V2
  describe Catalog do
    let(:broker) { VCAP::CloudController::ServiceBroker.make }

    def service_entry(opts = {})
      {
        'id'          => opts[:id] || Sham.guid,
        'name'        => opts[:name] || Sham.name,
        'description' => Sham.description,
        'bindable'    => true,
        'tags'        => ['magical', 'webscale'],
        'plans'       => opts[:plans] || [plan_entry]
      }
    end

    def plan_entry(opts={})
      {
        'id'          => opts[:id] || Sham.guid,
        'name'        => opts[:name] || Sham.name,
        'description' => Sham.description,
      }
    end

    let(:service_id) { Sham.guid }
    let(:service_name) { Sham.name }
    let(:service_description) { Sham.description }

    let(:plan_id) { Sham.guid }
    let(:plan_name) { Sham.name }
    let(:plan_description) { Sham.description }
    let(:service_metadata_hash) do
      {'metadata' => {'foo' => 'bar'}}
    end
    let(:plan_metadata_hash) do
      {'metadata' => { "cost" => "0.0" }}
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
            'plans'       => [
              {
                'id'          => plan_id,
                'name'        => plan_name,
                'description' => plan_description,
              }.merge(plan_metadata_hash)
            ]
          }.merge(service_metadata_hash)
        ]
      }
    end

    let(:catalog) { Catalog.new(broker, catalog_hash) }

    describe '#sync_services_and_plans' do
      it 'creates services from the catalog' do
        expect {
          catalog.sync_services_and_plans
        }.to change(VCAP::CloudController::Service, :count).by(1)

        service = VCAP::CloudController::Service.last
        expect(service.service_broker).to eq(broker)
        expect(service.label).to eq(service_name)
        expect(service.description).to eq(service_description)
        expect(service.bindable).to be_true
        expect(service.tags).to match_array(['mysql', 'relational'])
        expect(JSON.parse(service.extra)).to eq( {'foo' => 'bar'} )
      end

      context 'when catalog service metadata is nil' do
        let(:service_metadata_hash) { {'metadata' => nil} }

        it 'leaves the extra field as nil' do
          catalog.sync_services_and_plans
          service = VCAP::CloudController::Service.last
          expect(service.extra).to be_nil
        end
      end

      context 'when the catalog service has no metadata key' do
        let(:service_metadata_hash) { {} }

        it 'leaves the extra field as nil' do
          catalog.sync_services_and_plans
          service = VCAP::CloudController::Service.last
          expect(service.extra).to be_nil
        end
      end

      context 'when the plan does not exist in the database' do
        it 'creates plans from the catalog' do
          expect {
            catalog.sync_services_and_plans
          }.to change(VCAP::CloudController::ServicePlan, :count).by(1)

          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.service).to eq(VCAP::CloudController::Service.last)
          expect(plan.name).to eq(plan_name)
          expect(plan.description).to eq(plan_description)
          expect(JSON.parse(plan.extra)).to eq({ 'cost' => '0.0' })

          # This is a temporary default until cost information is collected from V2
          # services.
          expect(plan.free).to be_true
        end

        it 'marks the plan as private' do
          catalog.sync_services_and_plans
          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.public).to be_false
        end
      end

      context 'when the catalog service plan metadata is empty' do
        let(:plan_metadata_hash) { {'metadata' => nil} }

        it 'leaves the plan extra field as nil' do
          catalog.sync_services_and_plans
          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.extra).to be_nil
        end
      end

      context 'when the catalog service plan has no metadata key' do
        let(:plan_metadata_hash) { {} }

        it 'leaves the plan extra field as nil' do
          catalog.sync_services_and_plans
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
            catalog.sync_services_and_plans
          }.to_not change(VCAP::CloudController::Service, :count)

          service.reload
          expect(service.label).to eq(service_name)
          expect(service.description).to eq(service_description)
        end

        it 'creates the new plan' do
          expect {
            catalog.sync_services_and_plans
          }.to change(VCAP::CloudController::ServicePlan, :count).by(1)

          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.service).to eq(VCAP::CloudController::Service.last)
          expect(plan.name).to eq(plan_name)
          expect(plan.description).to eq(plan_description)

          # This is a temporary default until cost information is collected from V2
          # services.
          expect(plan.free).to be_true
        end

        context 'and a plan already exists' do
          let!(:plan) do
            VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: plan_id
            )
          end

          it 'updates the existing plan' do
            expect(plan.name).to_not eq(plan_name)
            expect(plan.description).to_not eq(plan_description)

            expect {
              catalog.sync_services_and_plans
            }.to_not change(VCAP::CloudController::ServicePlan, :count)

            plan.reload
            expect(plan.name).to eq(plan_name)
            expect(plan.description).to eq(plan_description)
          end

          context 'when the plan is public' do
            before do
              plan.update(public: true)
            end

            it 'does not make it public' do
              catalog.sync_services_and_plans
              plan.reload
              expect(plan.public).to be_true
            end
          end
        end

        context 'and a plan exists that has been removed from the broker catalog' do
          let!(:plan) do
            VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: 'nolongerexists'
            )
          end

          it 'deletes the plan from the db' do
            catalog.sync_services_and_plans
            expect(VCAP::CloudController::ServicePlan.find(:id => plan.id)).to be_nil
          end

          context 'when an instance for the plan exists' do
            it 'marks the existing plan as inactive' do
              VCAP::CloudController::ManagedServiceInstance.make(service_plan: plan)
              expect(plan).to be_active

              catalog.sync_services_and_plans
              plan.reload

              expect(plan).not_to be_active
            end
          end
        end
      end

      context 'when a service no longer exists' do
        let!(:service) do
          VCAP::CloudController::Service.make(
            service_broker: broker,
            unique_id: 'nolongerexists'
          )
        end

        it 'should delete the service' do
          catalog.sync_services_and_plans
          expect(VCAP::CloudController::Service.find(:id => service.id)).to be_nil
        end

        context 'but it has an active plan' do
          let!(:plan) do
            VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: 'also_no_longer_in_catalog'
            )
          end
          let!(:service_instance) do
            VCAP::CloudController::ManagedServiceInstance.make(service_plan: plan)
          end

          it 'marks the existing service as inactive' do
            expect(service).to be_active

            catalog.sync_services_and_plans
            service.reload

            expect(service).not_to be_active
          end
        end

      end

      describe 'creating dashboard clients for sso' do
        let(:catalog_hash) do
          {
            'services' => [
              {
                'id'          => Sham.guid,
                'name'        => 'service-with-dashboard-client',
                'description' => service_description,
                'bindable'    => true,
                'dashboard_client' => dashboard_client_attrs,
                'tags'        => ['mysql', 'relational'],
                'plans'       => [
                  {
                    'id'          => plan_id,
                    'name'        => plan_name,
                    'description' => plan_description,
                  }.merge(plan_metadata_hash)
                ]
              }.merge(service_metadata_hash),
              {
                'id'          => Sham.guid,
                'name'        => 'service-without-dashboard-client',
                'description' => service_description,
                'bindable'    => true,
                'tags'        => ['mysql', 'relational'],
                'plans'       => [
                  {
                    'id'          => Sham.guid,
                    'name'        => Sham.name,
                    'description' => plan_description,
                  }.merge(plan_metadata_hash)
                ]
              }.merge(service_metadata_hash)
            ]
          }
        end

        it 'persists a dashboard client id for each service that is configured with one' do
          ServiceDashboardClientManager.stub(:create).once
          catalog.sync_services_and_plans

          expect(VCAP::CloudController::Service.find(label: 'service-with-dashboard-client').sso_client_id).to eq 'abcde123'
          expect(VCAP::CloudController::Service.find(label: 'service-without-dashboard-client').sso_client_id).to be_nil
        end
      end
    end

    describe '#create_service_dashboard_clients' do
      let(:catalog_hash) do
        {
          'services' => [
            {
              'id'          => 'service-with-dashboard-client-id',
              'name'        => 'service-with-dashboard-client',
              'description' => service_description,
              'bindable'    => true,
              'dashboard_client' => dashboard_client_attrs,
              'tags'        => ['mysql', 'relational'],
              'plans'       => [
                {
                  'id'          => plan_id,
                  'name'        => plan_name,
                  'description' => plan_description,
                }.merge(plan_metadata_hash)
              ]
            }.merge(service_metadata_hash),
            {
              'id'          => Sham.guid,
              'name'        => 'service-without-dashboard-client',
              'description' => service_description,
              'bindable'    => true,
              'tags'        => ['mysql', 'relational'],
              'plans'       => [
                {
                  'id'          => Sham.guid,
                  'name'        => Sham.name,
                  'description' => plan_description,
                }.merge(plan_metadata_hash)
              ]
            }.merge(service_metadata_hash),
            {
              'id'               => 'other-service-with-dashboard-client-id',
              'name'             => 'other-service-with-dashboard-client',
              'description'      => service_description,
              'bindable'         => true,
              'dashboard_client' => {
                'id'           => 'otherid',
                'secret'       => 'top-sekret',
                'redirect_uri' => 'http://redirect.com'
              },
              'tags'             => ['mysql', 'relational'],
              'plans'            => [
                {
                  'id'          => Sham.guid,
                  'name'        => Sham.name,
                  'description' => plan_description,
                }.merge(plan_metadata_hash)
              ]
            }.merge(service_metadata_hash),
          ]
        }
      end
      let(:client_manager) { double('client_manager') }

      before do
        allow(ServiceDashboardClientManager).to receive(:new).and_return(client_manager)
      end

      context 'when clients we want to create already exist in uaa' do
        before do
          allow(client_manager).to receive(:get_clients).with([ dashboard_client_attrs['id'], 'otherid' ]).
            and_return([ { 'client_id' => dashboard_client_attrs['id'] } ])
        end

        context 'and the service exists in the db with a matching sso_client_id' do
          before do
            VCAP::CloudController::Service.make(unique_id: 'service-with-dashboard-client-id', sso_client_id: dashboard_client_attrs['id'])
            allow(client_manager).to receive(:create)
          end

          it 'does not create that client' do
            catalog.create_service_dashboard_clients

            expect(client_manager).to_not have_received(:create).with(dashboard_client_attrs)
          end
        end

        context 'and the service does not have a matching sso_client_id in the db' do
          before do
            allow(client_manager).to receive(:create)
          end

          it 'creates no clients' do
            catalog.create_service_dashboard_clients rescue nil

            expect(client_manager).to_not have_received(:create)
          end

          it 'adds an error to the catalog service' do
            catalog.create_service_dashboard_clients rescue nil
            service_with_client = catalog.services.find { |s| s.name == 'service-with-dashboard-client' }

            expect(service_with_client.errors).to include 'Service dashboard client id must be unique'
          end

          it 'raises a ServiceBrokerCatalogInvalid error' do
            expect { catalog.create_service_dashboard_clients }.to raise_error(VCAP::Errors::ServiceBrokerCatalogInvalid)
          end
        end
      end

      context 'when some clients we want to create do not already exist in uaa' do
        before do
          VCAP::CloudController::Service.make(unique_id: 'other-service-with-dashboard-client-id', sso_client_id: 'otherid')
          allow(client_manager).to receive(:get_clients).with([dashboard_client_attrs['id'], 'otherid']).
            and_return([{ 'client_id' => 'otherid' }])
          allow(client_manager).to receive(:create)
        end

        it 'creates the clients' do
          catalog.create_service_dashboard_clients

          expect(client_manager).to have_received(:create).once
          expect(client_manager).to have_received(:create).with(dashboard_client_attrs)
        end
      end
    end

    describe 'validations' do
      context 'when the catalog is invalid' do
        let(:catalog_hash) do
          {
            'services' => [
              service_entry,
              service_entry(id: 123),
              service_entry(plans: [plan_entry(id: 'plan-id'), plan_entry(id: 'plan-id', name: 123)]),
              service_entry(plans: [])
            ]
          }
        end

        specify '#valid? returns false and #error_text includes all error messages' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
        end
      end
    end

    describe '#error_text' do
      let(:catalog_hash) do
        {
          'services' => [
            service_entry(name: 'service-1'),
            service_entry(name: 'service-2', id: 123),
            service_entry(name: 'service-3',
                          plans: [ plan_entry(name: 'plan-1', id: 'plan-id'),
                                   plan_entry(id: 'plan-id', name: 123) ]),
            service_entry(name: 'service-4', plans: [])
          ]
        }
      end

      it 'builds a formatted string' do
        catalog = Catalog.new(broker, catalog_hash)
        catalog.valid?

        expect(catalog.error_text).to eq(
<<-HEREDOC

Service service-2
  Service id must be a string, but has value 123
Service service-3
  Plan id must be unique
  Plan 123
    Plan name must be a string, but has value 123
Service service-4
  At least one plan is required
HEREDOC
        )
      end
    end
  end
end
