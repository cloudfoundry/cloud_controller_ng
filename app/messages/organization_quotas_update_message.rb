require 'messages/metadata_base_message'
require 'messages/validators'
require 'messages/quotas_apps_message'
require 'messages/quotas_services_message'
require 'messages/quotas_routes_message'

module VCAP::CloudController
  class OrganizationQuotasUpdateMessage < BaseMessage
    MAX_ORGANIZATION_QUOTA_NAME_LENGTH = 250

    def self.key_requested?(key)
      proc { |a| a.requested?(key) }
    end

    register_allowed_keys [:name, :apps, :services, :routes, :domains]
    validates_with NoAdditionalKeysValidator

    validates :name,
      string: true,
      length: { minimum: 1, maximum: MAX_ORGANIZATION_QUOTA_NAME_LENGTH },
      if: key_requested?(:name)

    validate :apps_validator, if: key_requested?(:apps)
    validate :services_validator, if: key_requested?(:services)
    validate :routes_validator, if: key_requested?(:routes)
    validate :domains_validator, if: key_requested?(:domains)

    # Apps validations
    delegate :total_memory_in_mb, :per_process_memory_in_mb, :total_instances, :per_app_tasks, to: :apps_limits_message

    def validates_hash(key, sym)
      return true if key.is_a?(Hash)

      errors[sym].concat(['must be an object'])
      false
    end

    def apps_validator
      return unless validates_hash(apps, :apps)

      errors[:apps].concat(apps_limits_message.errors.full_messages) unless apps_limits_message.valid?
    end

    def apps_limits_message
      @apps_limits_message ||= QuotasAppsMessage.new(apps&.deep_symbolize_keys)
    end

    # Services validations
    delegate :total_service_keys, :total_service_instances, :paid_services_allowed, to: :services_limits_message

    def services_validator
      return unless validates_hash(services, :services)

      errors[:services].concat(services_limits_message.errors.full_messages) unless services_limits_message.valid?
    end

    def services_limits_message
      @services_limits_message ||= QuotasServicesMessage.new(services&.deep_symbolize_keys)
    end

    # Routes validations
    delegate :total_routes, :total_reserved_ports, to: :routes_limits_message

    def routes_validator
      return unless validates_hash(routes, :routes)

      errors[:routes].concat(routes_limits_message.errors.full_messages) unless routes_limits_message.valid?
    end

    def routes_limits_message
      @routes_limits_message ||= QuotasRoutesMessage.new(routes&.deep_symbolize_keys)
    end

    # domains validations
    delegate :total_domains, to: :domains_limits_message

    def domains_validator
      return unless validates_hash(domains, :domains)

      errors[:domains].concat(domains_limits_message.errors.full_messages) unless domains_limits_message.valid?
    end

    def domains_limits_message
      @domains_limits_message ||= DomainsLimitsMessage.new(domains&.deep_symbolize_keys)
    end
  end

  class DomainsLimitsMessage < BaseMessage
    register_allowed_keys [:total_domains]

    validates_with NoAdditionalKeysValidator

    validates :total_domains,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true
  end
end
