require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class SpaceQuotaUpdateMessage < BaseMessage
    MAX_SPACE_QUOTA_NAME_LENGTH = 250

    def self.key_requested?(key)
      proc { |a| a.requested?(key) }
    end

    register_allowed_keys [:name, :apps, :services, :routes]
    validates_with NoAdditionalKeysValidator

    validates :name,
      string: true,
      presence: true,
      length: { minimum: 1, maximum: MAX_SPACE_QUOTA_NAME_LENGTH },
      if: key_requested?(:name)

    validate :apps_validator, if: key_requested?(:apps)
    validate :services_validator, if: key_requested?(:services)
    validate :routes_validator, if: key_requested?(:routes)

    delegate :total_memory_in_mb, :per_process_memory_in_mb, :total_instances, :per_app_tasks, :log_rate_limit_in_bytes_per_second, to: :apps_limits_message
    delegate :paid_services_allowed, :total_service_instances, :total_service_keys, to: :services_limits_message
    delegate :total_routes, :total_reserved_ports, to: :routes_limits_message

    def validates_hash(key, sym)
      return true if key.is_a?(Hash)

      errors.add(sym, message: 'must be an object')
      false
    end

    def apps_validator
      return unless validates_hash(apps, :apps)

      return if apps_limits_message.valid?

      apps_limits_message.errors.full_messages.each do |message|
        errors.add(:apps, message: message)
      end
    end

    def apps_limits_message
      @apps_limits_message ||= QuotasAppsMessage.new(apps&.deep_symbolize_keys)
    end

    def services_validator
      return unless validates_hash(services, :services)

      return if services_limits_message.valid?

      services_limits_message.errors.full_messages.each do |message|
        errors.add(:services, message: message)
      end
    end

    def services_limits_message
      @services_limits_message ||= QuotasServicesMessage.new(services&.deep_symbolize_keys)
    end

    def routes_validator
      return unless validates_hash(routes, :routes)

      return if routes_limits_message.valid?

      routes_limits_message.errors.full_messages.each do |message|
        errors.add(:routes, message: message)
      end
    end

    def routes_limits_message
      @routes_limits_message ||= QuotasRoutesMessage.new(routes&.deep_symbolize_keys)
    end
  end
end
