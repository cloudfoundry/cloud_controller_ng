module VCAP::Services::ServiceBrokers::V2
  class CatalogService
    include CatalogValidationHelper

    SUPPORTED_REQUIRES_VALUES = ['syslog_drain', 'route_forwarding', 'volume_mount'].freeze

    attr_reader :service_broker, :broker_provided_id, :metadata, :name,
      :description, :bindable, :tags, :plans, :requires, :dashboard_client, :errors, :plan_updateable

    def initialize(service_broker, attrs)
      @service_broker     = service_broker
      @broker_provided_id = attrs['id']
      @metadata           = attrs['metadata']
      @name               = attrs['name']
      @description        = attrs['description']
      @bindable           = attrs['bindable']
      @tags               = attrs.fetch('tags', [])
      @requires           = attrs.fetch('requires', [])
      @plans_data         = attrs['plans']
      @dashboard_client   = attrs['dashboard_client']
      @plan_updateable    = attrs['plan_updateable'] || false
      @errors             = VCAP::Services::ValidationErrors.new
      @plans              = []

      build_plans
    end

    def valid?
      return @valid if defined? @valid
      validate_service
      validate_plans
      @valid = errors.empty?
    end

    def plans_present?
      plans && !plans.empty?
    end

    def cc_service
      service_broker.services_dataset.where(unique_id: broker_provided_id).first
    end

    def route_service?
      requires.include?('route_forwarding')
    end

    def volume_mount_service?
      requires.include?('volume_mount')
    end

    private

    attr_reader :plans_data

    def validate_service
      validate_string!(:broker_provided_id, broker_provided_id, required: true)
      validate_string!(:name, name, required: true)
      validate_string!(:description, description, required: true)
      validate_bool!(:bindable, bindable, required: true)
      validate_bool!(:plan_updateable, plan_updateable, required: true)

      validate_tags!(:tags, tags)
      validate_array_of_strings!(:requires, requires)

      validate_hash!(:metadata, metadata) if metadata
      validate_dashboard_client!
      validate_requires
    end

    def validate_plans
      validate_dependently_in_order([
        :validate_at_least_one_plan_present!,
        :validate_plans_format,
        :validate_plans_data,
        :validate_uniqueness_constraints
      ])
    end

    def validate_plans_format
      validate_array_of_hashes!(:plans, plans_data)
    end

    def validate_uniqueness_constraints
      validate_all_plan_ids_are_unique!
      validate_all_plan_names_are_unique!
    end

    def validate_plans_data
      plans.each do |plan|
        errors.add_nested(plan, plan.errors) unless plan.valid?
      end
    end

    def validate_requires
      return unless requires.is_a? Enumerable
      requires.
        reject { |v| SUPPORTED_REQUIRES_VALUES.include? v }.
        each { |v| errors.add(%(Service "requires" field contains unsupported value "#{v}")) }
    end

    def build_plans
      return unless plans_data

      @plans = if plans_data.is_a?(Array)
                 @plans_data.map { |attrs| CatalogPlan.new(self, attrs) }
               else
                 @plans_data
               end
    end

    def validate_at_least_one_plan_present!
      errors.add('At least one plan is required') if plans.empty?
    end

    def validate_all_plan_ids_are_unique!
      duplicate_plans = find_duplicate_plans :broker_provided_id
      if duplicate_plans
        duplicate_plans.each do |plan|
          errors.add("Plan ids must be unique within a service. Service #{name} already has a plan with id '#{plan}'")
        end
      end
    end

    def validate_all_plan_names_are_unique!
      duplicate_plans = find_duplicate_plans :name
      if duplicate_plans.present?
        duplicate_plans.each do |plan|
          errors.add("Plan names must be unique within a service. Service #{name} already has a plan named #{plan}")
        end
      end
    end

    def find_duplicate_plans(field)
      plan_names = plans.map(&field)
      duplicate_plans = plan_names.find_all { |plan| plan_names.count(plan) > 1 }
      duplicate_plans.uniq
    end

    def validate_dashboard_client!
      return unless dashboard_client
      validate_dependently_in_order([
        :validate_dashboard_client_is_a_hash!,
        :validate_dashboard_client_attributes!
      ])
    end

    def validate_dashboard_client_is_a_hash!
      validate_hash!(:dashboard_client, dashboard_client)
    end

    def validate_dashboard_client_attributes!
      validate_string!(:dashboard_client_id, dashboard_client['id'], required: true)
      validate_string!(:dashboard_client_secret, dashboard_client['secret'], required: true)
      validate_string!(:dashboard_client_redirect_uri, dashboard_client['redirect_uri'], required: true)
    end

    def human_readable_attr_name(name)
      {
        broker_provided_id: 'Service id',
        name: 'Service name',
        description: 'Service description',
        bindable: 'Service "bindable" field',
        plan_updateable: 'Service "plan_updateable" field',
        tags: 'Service tags',
        metadata: 'Service metadata',
        plans: 'Service plans list',
        requires: 'Service "requires" field',
        dashboard_client: 'Service dashboard client attributes',
        dashboard_client_id: 'Service dashboard client id',
        dashboard_client_secret: 'Service dashboard client secret',
        dashboard_client_redirect_uri: 'Service dashboard client redirect_uri'
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
