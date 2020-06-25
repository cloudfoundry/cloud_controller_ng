require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe Catalog do
    let(:broker) { VCAP::CloudController::ServiceBroker.make }

    def service_entry(opts={})
      {
          'id' => opts[:id] || Sham.guid,
          'name' => opts[:name] || Sham.name,
          'description' => Sham.description,
          'bindable' => true,
          'tags' => ['magical', 'webscale'],
          'plans' => opts[:plans] || [plan_entry]
      }
    end

    def plan_entry(opts={})
      {
          'id' => opts[:id] || Sham.guid,
          'name' => opts[:name] || Sham.name,
          'description' => Sham.description,
      }
    end

    let(:catalog) { Catalog.new(broker, catalog_hash) }

    def build_service(attrs={})
      @index ||= 0
      @index += 1
      {
          'id' => @index.to_s,
          'name' => @index.to_s,
          'description' => 'the service description',
          'bindable' => true,
          'tags' => ['tag1'],
          'metadata' => { 'foo' => 'bar' },
          'plans' => [
            {
                'id' => @index.to_s,
                'name' => @index.to_s,
                'description' => 'the plan description',
                'metadata' => { 'foo' => 'bar' }
            }
          ]
      }.merge(attrs)
    end

    describe 'validations' do
      context "when the catalog's services include errors" do
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

        specify '#valid? returns false' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.nested_errors).not_to be_empty
        end
      end

      context 'when two services in the catalog have the same id' do
        let(:catalog_hash) do
          {
              'services' => [build_service('id' => '1'), build_service('id' => '1')]
          }
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to include('Service ids must be unique')
        end
      end

      context 'unique service names' do
        context 'when two services in the catalog have the same name' do
          let(:catalog_hash) do
            {
              'services' => [
                build_service('id' => '1', 'name' => 'my-service'),
                build_service('id' => '2', 'name' => 'my-service')
              ]
            }
          end

          it 'gives an error' do
            catalog = Catalog.new(broker, catalog_hash)
            expect(catalog.valid?).to eq false
            expect(catalog.errors.messages).to include('Service names must be unique within a broker')
          end
        end

        context 'when the broker is being created and has not yet been persisted' do
          let(:broker) {
            VCAP::CloudController::ServiceBroker.new(name: 'not-persisted')
          }
          let(:catalog_hash) do
            {
              'services' => [build_service('id' => '1')]
            }
          end

          it 'is does not check for preexistent services' do
            catalog = Catalog.new(broker, catalog_hash)

            expect(catalog.valid?).to eq true
          end
        end

        context 'when a service in the catalog has the same name as a preexistent one for same broker' do
          context 'when ids provided by the broker are different' do
            context 'when there are service instances for a plan of that offering' do
              let(:new_catalog_hash) do
                {
                  'services' => [
                    build_service('id' => '1', 'name' => 'clashing-service-name'),
                    build_service('id' => '2', 'name' => 'clashing-service-name2')
                  ]
                }
              end
              let(:broker) {
                broker = VCAP::CloudController::ServiceBroker.make
                old_service = VCAP::CloudController::Service.make(label: 'clashing-service-name', service_broker: broker)
                old_plan = VCAP::CloudController::ServicePlan.make(service: old_service)
                VCAP::CloudController::ManagedServiceInstance.make(service_plan: old_plan)

                old_service = VCAP::CloudController::Service.make(label: 'clashing-service-name2', service_broker: broker)
                old_plan = VCAP::CloudController::ServicePlan.make(service: old_service)
                VCAP::CloudController::ManagedServiceInstance.make(service_plan: old_plan)

                broker
              }

              it 'is invalid' do
                catalog = Catalog.new(broker, new_catalog_hash)

                expect(catalog.valid?).to be false
                expect(catalog.errors.messages).to include(
                  include('Service names must be unique within a broker') &
                  include('clashing-service-name2') &
                  include('clashing-service-name') &
                  end_with('already exist')
                )
              end
            end

            context 'when there are no service instances for a plan of that offering' do
              let(:new_catalog_hash) do
                {
                  'services' => [build_service('id' => '1', 'name' => 'clashing-service-name')]
                }
              end
              let(:broker) { VCAP::CloudController::ServiceBroker.make }
              let(:old_service) { VCAP::CloudController::Service.make(label: 'clashing-service-name', service_broker: broker) }
              let!(:old_plan) { VCAP::CloudController::ServicePlan.make(service: old_service) }

              it 'is valid' do
                catalog = Catalog.new(broker, new_catalog_hash)

                expect(catalog.valid?).to be true
              end
            end
          end

          context 'when ids provided by the broker are the same' do
            let(:broker) { VCAP::CloudController::ServiceBroker.make }
            let(:old_service) { VCAP::CloudController::Service.make(label: 'clashing-service-name', service_broker: broker) }
            let(:new_catalog_hash) do
              {
                'services' => [build_service('id' => old_service.unique_id, 'name' => old_service.label)]
              }
            end
            let(:old_plan) { VCAP::CloudController::ServicePlan.make(service: old_service) }
            let!(:instance) { VCAP::CloudController::ManagedServiceInstance.make(service_plan: old_plan) }

            it 'is valid' do
              catalog = Catalog.new(broker, new_catalog_hash)

              expect(catalog.valid?).to be true
            end
          end
        end

        context 'when a service in the catalog has the same name as a service from a different broker' do
          let(:catalog_hash) do
            {
                'services' => [build_service('id' => '1'), build_service('id' => '2')]
            }
          end
          let(:broker) { VCAP::CloudController::ServiceBroker.make }

          let(:another_broker) {
            broker = VCAP::CloudController::ServiceBroker.make
            old_service = VCAP::CloudController::Service.make(name: '1', service_broker: broker)
            old_plan = VCAP::CloudController::ServicePlan.make(service: old_service)
            VCAP::CloudController::ManagedServiceInstance.make(service_plan: old_plan)

            broker
          }

          it 'is valid' do
            catalog = Catalog.new(broker, catalog_hash)

            expect(catalog.valid?).to eq true
          end
        end
      end

      context 'when two services in the catalog have the same dashboard_client id' do
        let(:catalog_hash) do
          {
              'services' => [
                build_service('dashboard_client' => {
                    'id' => 'client-1',
                    'secret' => 'secret',
                    'redirect_uri' => 'http://example.com/client-1'
                }),
                build_service('dashboard_client' => {
                    'id' => 'client-1',
                    'secret' => 'secret2',
                    'redirect_uri' => 'http://example.com/client-2'
                }),
              ]
          }
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to include('Service dashboard_client id must be unique')
        end
      end

      context "when a service's dashboard_client attribute is not a hash" do
        let(:catalog_hash) do
          { 'services' => [build_service('dashboard_client' => 1)] }
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
        end
      end

      context 'when there are multiple services without a dashboard_client' do
        let(:catalog_hash) do
          { 'services' => [build_service, build_service] }
        end

        it 'does not give a uniqueness error on dashboard_client id' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq true
        end
      end

      context 'when there are multiple services with a nil dashboard_client id' do
        let(:catalog_hash) do
          {
              'services' => [
                build_service('dashboard_client' => { 'id' => nil }),
                build_service('dashboard_client' => { 'id' => nil })
              ]
          }
        end

        it 'is invalid, but not due to uniqueness constraints' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to eq []
        end
      end

      context 'when there are multiple services with an empty id' do
        let(:catalog_hash) do
          { 'services' => [build_service('id' => nil), build_service('id' => nil)] }
        end

        it 'is invalid, but not due to uniqueness constraints' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to eq []
        end
      end

      context 'when there are both service validation problems and uniqueness problems' do
        let(:catalog_hash) do
          {
              'services' => [
                build_service('id' => 'service-1', 'dashboard_client' => { 'id' => 'client-1' }),
                build_service('id' => 'service-1', 'dashboard_client' => { 'id' => 'client-1' }),
              ]
          }
        end
        let(:catalog) { Catalog.new(broker, catalog_hash) }

        it 'is not valid' do
          expect(catalog).not_to be_valid
        end

        it 'has validation errors on the service' do
          catalog.valid?
          expect(catalog.errors.nested_errors).not_to be_empty
        end

        it 'has a validation error for duplicate service ids' do
          catalog.valid?
          expect(catalog.errors.messages).to include('Service ids must be unique')
        end

        it 'has a validation error for duplicate dashboard_client ids' do
          catalog.valid?
          expect(catalog.errors.messages).to include('Service dashboard_client id must be unique')
        end
      end
    end

    describe 'incompatibilities' do
      context 'when the catalog has no services with route forwarding or volume mounts' do
        let(:catalog_hash) do
          {
              'services' => [
                build_service('requires' => []),
                build_service('requires' => []),
              ]
          }
        end

        context 'when the CF config has route forwarding and volume mounts disabled' do
          before do
            TestConfig.config[:volume_services_enabled] = false
            TestConfig.config[:route_services_enabled] = false
          end

          it 'is compatible and there are no compatibility errors' do
            expect(catalog.compatible?).to be(true)
            expect(catalog.incompatibility_errors.messages).to be_empty
          end
        end
      end

      context 'when the catalog has a services with route forwarding and volume mounts' do
        let(:catalog_hash) do
          {
              'services' => [
                build_service('requires' => []),
                build_service('requires' => %w(route_forwarding)),
                build_service('requires' => %w(volume_mount)),
                build_service('requires' => %w(route_forwarding volume_mount))
              ]
          }
        end

        context 'when the CF config has route forwarding and volume mounts enabled' do
          before do
            TestConfig.config[:volume_services_enabled] = true
            TestConfig.config[:route_services_enabled] = true
          end

          it 'is compatible and there are no compatibility errors' do
            expect(catalog.compatible?).to be(true)
            expect(catalog.incompatibility_errors.messages).to be_empty
          end
        end

        context 'when the CF config has route forwarding disabled' do
          before do
            TestConfig.config[:volume_services_enabled] = true
            TestConfig.config[:route_services_enabled] = false
          end

          it 'is not compatible and there are few compatibility errors' do
            expect(catalog.compatible?).to be(false)
            expect(catalog.incompatibility_errors.messages).to eq([
              'Service 2 is declared to be a route service but support for route services is disabled.',
              'Service 4 is declared to be a route service but support for route services is disabled.'
            ])
          end
        end

        context 'when the CF config has volume mounts disabled' do
          before do
            TestConfig.config[:volume_services_enabled] = false
            TestConfig.config[:route_services_enabled] = true
          end

          it 'is not compatible and there are few compatibility errors' do
            expect(catalog.compatible?).to be(false)
            expect(catalog.incompatibility_errors.messages).to eq([
              'Service 3 is declared to be a volume mount service but support for volume mount services is disabled.',
              'Service 4 is declared to be a volume mount service but support for volume mount services is disabled.'
            ])
          end
        end

        context 'when the CF config has route forwarding and volume mounts disabled' do
          before do
            TestConfig.config[:volume_services_enabled] = false
            TestConfig.config[:route_services_enabled] = false
          end

          it 'is not compatible and there are few compatibility errors' do
            expect(catalog.compatible?).to be(false)
            expect(catalog.incompatibility_errors.messages).to eq([
              'Service 2 is declared to be a route service but support for route services is disabled.',
              'Service 3 is declared to be a volume mount service but support for volume mount services is disabled.',
              'Service 4 is declared to be a route service but support for route services is disabled.',
              'Service 4 is declared to be a volume mount service but support for volume mount services is disabled.'
            ])
          end
        end
      end
    end
  end
end
