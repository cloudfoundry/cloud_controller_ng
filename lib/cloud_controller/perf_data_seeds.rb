require 'cloud_controller/adjective_noun_generator'
require 'securerandom'
require 'timeout'

PREFIX = 'perf'.freeze

NUM_ORGS = 22000
NUM_SPACES = NUM_ORGS * 3
NUM_SERVICE_BROKERS = 300
NUM_SERVICE_PLANS = 1200
NUM_SERVICES = NUM_SERVICE_BROKERS * 2
NUM_SERVICE_INSTANCES = 10000
NUM_SERVICE_PLAN_VISIBILITIES = NUM_ORGS * 30

module VCAP::CloudController
  module PerfDataSeeds
    class << self
      def write_seed_data(config)
        create_orgs NUM_ORGS
        create_spaces NUM_SPACES
        create_service_brokers NUM_SERVICE_BROKERS
        create_services NUM_SERVICES
        create_service_plans NUM_SERVICE_PLANS
        create_service_instances (NUM_SERVICE_INSTANCES / 2).to_i, managed: true
        create_service_instances (NUM_SERVICE_INSTANCES / 2).to_i, managed: false
        create_service_plan_visibilities NUM_SERVICE_PLAN_VISIBILITIES
      end

      def create_orgs(num_orgs)
        puts "Creating #{num_orgs} Orgs"
        orgs = num_orgs.times.map do |i|
          org_uuid = SecureRandom.uuid
          Organization.new(name: "#{PREFIX}-org-#{org_uuid}", guid: org_uuid, quota_definition_id: 1)
        end
        Organization.multi_insert(orgs)
      end

      def create_spaces(num_spaces)
        puts "Creating #{num_spaces} Spaces"
        all_orgs = Organization.all
        spaces = num_spaces.times.map do |i|
          space_uuid = SecureRandom.uuid
          Space.new(name: "#{PREFIX}-space-#{space_uuid}", organization: all_orgs.sample, guid: space_uuid)
        end
        Space.multi_insert(spaces)
      end

      def create_service_brokers(num_service_brokers)
        puts "Creating #{num_service_brokers} Service Brokers"
        brokers = num_service_brokers.times.map do |i|
          service_broker_uuid = SecureRandom.uuid
          ServiceBroker.new(name: "#{PREFIX}-service-broker-#{service_broker_uuid}", broker_url: 'https://vcap.me',
            auth_username: 'user', auth_password: 'pass', guid: service_broker_uuid)
        end
        ServiceBroker.multi_insert(brokers)
      end

      def create_services(num_services)
        puts "Creating #{num_services} Services"
        all_brokers = ServiceBroker.all
        services = num_services.times.map do |i|
          service_guid = SecureRandom.uuid
          Service.new(label: "#{PREFIX}-service-#{service_guid}", description: "service #{service_guid}",
            bindable: [true, false].sample, service_broker_id: all_brokers.sample.id, guid: service_guid)
        end
        Service.multi_insert(services)
      end

      def create_service_plans(num_service_plans)
        puts "Creating #{num_service_plans} Service Plans"
        all_services = Service.all
        service_plans = num_service_plans.times.map do |j|
          service = all_services.sample
          service_plan_uuid = SecureRandom.uuid
          ServicePlan.new(name: "#{PREFIX}-service-plan-#{service.guid}-#{service_plan_uuid}", service: service, description: "service plan for service #{service.guid}",
            free: [true, false].sample, public: [true, false].sample, guid: service_plan_uuid, unique_id: service_plan_uuid)
        end
        ServicePlan.multi_insert(service_plans)
      end

      def create_service_instances(num_service_instances, managed: true)
        puts "Creating #{num_service_instances} Service Instances distributed over all orgs and spaces"
        all_service_plans = ServicePlan.all
        all_spaces = Space.all
        managed_service_instances = num_service_instances.times.map do |i|
          ManagedServiceInstance.new(name: "#{PREFIX}-service-instance-#{SecureRandom.uuid}", space: all_spaces.sample, is_gateway_service: managed,
                                 service_plan_id: all_service_plans.sample.id)
        end
        ManagedServiceInstance.multi_insert(managed_service_instances)
      end

      def create_service_plan_visibilities(num_service_plan_visibilities)
        puts "Creating #{num_service_plan_visibilities} Service Plan Visibilities distributed over all orgs"
        all_plans = ServicePlan.all
        service_plan_visibilities = Organization.map do |o|
          all_plans.sample((num_service_plan_visibilities / NUM_ORGS).to_i).map do |p|
            ServicePlanVisibility.new(guid: SecureRandom.uuid, organization: o, service_plan: p)
          end
        end.flatten
        ServicePlanVisibility.multi_insert(service_plan_visibilities)
      end
    end
  end
end
