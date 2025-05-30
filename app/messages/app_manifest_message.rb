require 'messages/base_message'
require 'messages/manifest_process_scale_message'
require 'messages/manifest_process_update_message'
require 'messages/manifest_buildpack_message'
require 'messages/manifest_service_binding_create_message'
require 'messages/manifest_routes_update_message'
require 'messages/validators/metadata_validator'
require 'cloud_controller/app_manifest/byte_converter'
require 'models/helpers/health_check_types'
require 'presenters/helpers/censorship'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    register_allowed_keys %i[
      buildpack
      buildpacks
      command
      disk_quota
      log_rate_limit_per_second
      docker
      env
      health_check_http_endpoint
      health_check_invocation_timeout
      health_check_interval
      health_check_timeout
      health_check_type
      readiness_health_check_http_endpoint
      readiness_health_check_type
      readiness_health_check_invocation_timeout
      readiness_health_check_interval
      instances
      metadata
      memory
      lifecycle
      name
      no_route
      processes
      random_route
      default_route
      routes
      services
      sidecars
      stack
      timeout
      cnb_credentials
    ]

    HEALTH_CHECK_TYPE_MAPPING = { HealthCheckTypes::NONE => HealthCheckTypes::PROCESS }.freeze

    def self.create_from_yml(parsed_yaml)
      new(parsed_yaml, underscore_keys(parsed_yaml.deep_symbolize_keys))
    end

    def self.underscore_keys(hash)
      hash.each_with_object({}) do |(key, val), memo|
        new_key = key.to_s.underscore.to_sym
        memo[new_key] = if key == :processes && val.is_a?(Array)
                          val.map { |process| underscore_keys(process) }
                        else
                          val
                        end
      end
    end

    validates :name, presence: { message: 'must not be empty' }, string: true
    validate :validate_top_level_web_process!
    validate :validate_processes!, if: ->(record) { record.requested?(:processes) }
    validate :validate_sidecars!,  if: ->(record) { record.requested?(:sidecars) }
    validate :validate_manifest_process_scale_messages!
    validate :validate_manifest_process_update_messages!
    validate :validate_app_update_message!
    validate :validate_buildpack_and_buildpacks_combination!
    validate :validate_docker_enabled!
    validate :validate_cnb_enabled!
    validate :validate_docker_buildpacks_combination!
    validate :validate_service_bindings_message!, if: ->(record) { record.requested?(:services) }
    validate :validate_env_update_message!,       if: ->(record) { record.requested?(:env) }
    validate :validate_manifest_singular_buildpack_message!, if: ->(record) { record.requested?(:buildpack) }
    validate :validate_manifest_routes_update_message!,      if: lambda { |record|
      record.requested?(:routes) ||
        record.requested?(:no_route) ||
        record.requested?(:random_route) ||
        record.requested?(:default_route)
    }

    def initialize(original_yaml, attrs={})
      super(attrs)
      @original_yaml = original_yaml
    end

    def manifest_process_scale_messages
      @manifest_process_scale_messages ||= process_scale_attribute_mappings.map { |mapping| ManifestProcessScaleMessage.new(mapping) }
    end

    def manifest_process_update_messages
      @manifest_process_update_messages ||= process_update_attribute_mappings.map { |mapping| ManifestProcessUpdateMessage.new(mapping) }
    end

    def sidecar_create_messages
      @sidecar_create_messages ||= sidecar_create_attribute_mappings.map { |mapping| SidecarCreateMessage.new(mapping) }
    end

    def app_update_message
      @app_update_message ||= AppUpdateMessage.new(app_lifecycle_hash)
    end

    def app_update_environment_variables_message
      @app_update_environment_variables_message ||= UpdateEnvironmentVariablesMessage.new(env_update_attribute_mapping)
    end

    def manifest_service_bindings_message
      @manifest_service_bindings_message ||= ManifestServiceBindingCreateMessage.new(service_bindings_attribute_mapping)
    end

    def manifest_routes_update_message
      @manifest_routes_update_message ||= ManifestRoutesUpdateMessage.new(routes_attribute_mapping)
    end

    def audit_hash
      override_env = original_yaml['env'] ? { 'env' => Presenters::Censorship::PRIVATE_DATA_HIDDEN } : {}
      override_cnb = original_yaml['cnb-credentials'] ? { 'cnb-credentials' => Presenters::Censorship::PRIVATE_DATA_HIDDEN } : {}
      original_yaml.merge(override_env).merge(override_cnb)
    end

    def app_lifecycle_hash
      lifecycle_type = if requested?(:lifecycle) && @lifecycle == 'cnb'
                         Lifecycles::CNB
                       elsif requested?(:lifecycle) && @lifecycle == 'buildpack'
                         Lifecycles::BUILDPACK
                       elsif requested?(:docker)
                         Lifecycles::DOCKER
                       end

      data = {
        buildpacks: requested_buildpacks,
        stack: @stack,
        credentials: @cnb_credentials
      }.compact

      if lifecycle_type == Lifecycles::DOCKER
        lifecycle = {
          type: Lifecycles::DOCKER
        }
      elsif lifecycle_type || data.present?
        lifecycle = {}
        lifecycle[:type] = lifecycle_type if lifecycle_type.present?
        lifecycle[:data] = data if data.present?
      end

      {
        lifecycle: lifecycle,
        metadata: requested?(:metadata) ? metadata : nil
      }.compact
    end

    private

    attr_reader :original_yaml

    def manifest_buildpack_message
      @manifest_buildpack_message ||= ManifestBuildpackMessage.new(buildpack:)
    end

    def process_scale_attribute_mappings
      process_scale_attributes_from_app_level = process_scale_attributes(memory:,
                                                                         disk_quota:,
                                                                         log_rate_limit_per_second:,
                                                                         instances:)

      process_attributes(process_scale_attributes_from_app_level) do |process|
        process_scale_attributes(
          memory: process[:memory],
          disk_quota: process[:disk_quota],
          log_rate_limit_per_second: process[:log_rate_limit_per_second],
          instances: process[:instances],
          type: process[:type]
        )
      end
    end

    def process_update_attribute_mappings
      process_attributes(process_update_attributes_from_app_level) do |process|
        process_update_attributes_from_process(process)
      end
    end

    def process_attributes(app_attributes)
      process_attributes = app_attributes.empty? ? [] : [app_attributes.merge({ type: ProcessTypes::WEB })]

      if block_given? && requested?(:processes) && processes.is_a?(Array)
        web, other = processes.partition { |p| p[:type] == ProcessTypes::WEB }
        process_attributes = [yield(web.first)] unless web.empty?

        other.map do |process|
          process_attributes << yield(process)
        end
      end

      process_attributes
    end

    def process_scale_attributes(instances:, memory: nil, disk_quota: nil, log_rate_limit_per_second: nil, type: nil)
      memory_in_mb = convert_to_mb(memory)
      disk_in_mb = convert_to_mb(disk_quota)
      log_rate_limit_in_bytes_per_second = convert_to_bytes_per_second(log_rate_limit_per_second)
      {
        instances: instances,
        memory: memory_in_mb,
        disk_quota: disk_in_mb,
        log_rate_limit: log_rate_limit_in_bytes_per_second,
        type: type
      }.compact
    end

    def sidecar_create_attribute_mappings
      return [] unless requested?(:sidecars)

      sidecars.map do |sidecar|
        sidecar_create_attributes(name: sidecar[:name],
                                  memory: sidecar[:memory],
                                  command: sidecar[:command],
                                  process_types: sidecar[:process_types])
      end
    end

    def sidecar_create_attributes(name:, command:, memory: nil, process_types: nil)
      memory_in_mb = convert_to_mb(memory) || memory
      {
        name:,
        memory_in_mb:,
        command:,
        process_types:
      }.compact
    end

    def process_update_attributes_from_app_level
      mapping = {}
      mapping[:command] = command || 'null' if requested?(:command)
      mapping[:health_check_http_endpoint] = health_check_http_endpoint if requested?(:health_check_http_endpoint)
      mapping[:timeout] = timeout if requested?(:timeout)
      mapping[:health_check_invocation_timeout] = health_check_invocation_timeout if requested?(:health_check_invocation_timeout)
      mapping[:health_check_interval] = health_check_interval if requested?(:health_check_interval)
      mapping[:readiness_health_check_invocation_timeout] = readiness_health_check_invocation_timeout if requested?(:readiness_health_check_invocation_timeout)
      mapping[:readiness_health_check_interval] = readiness_health_check_interval if requested?(:readiness_health_check_interval)
      mapping[:readiness_health_check_http_endpoint] = readiness_health_check_http_endpoint if requested?(:readiness_health_check_http_endpoint)

      mapping[:health_check_type] = converted_health_check_type(health_check_type) if requested?(:health_check_type)

      mapping[:readiness_health_check_type] = converted_health_check_type(readiness_health_check_type) if requested?(:readiness_health_check_type)

      mapping
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def process_update_attributes_from_process(params)
      mapping = {}
      mapping[:command] = params[:command] || 'null' if params.key?(:command)
      mapping[:health_check_http_endpoint] = params[:health_check_http_endpoint] if params.key?(:health_check_http_endpoint)
      mapping[:health_check_timeout] = params[:health_check_timeout] if params.key?(:health_check_timeout)
      mapping[:health_check_invocation_timeout] = params[:health_check_invocation_timeout] if params.key?(:health_check_invocation_timeout)
      mapping[:health_check_interval] = params[:health_check_interval] if params.key?(:health_check_interval)
      mapping[:readiness_health_check_invocation_timeout] = params[:readiness_health_check_invocation_timeout] if params.key?(:readiness_health_check_invocation_timeout)
      mapping[:readiness_health_check_interval] = params[:readiness_health_check_interval] if params.key?(:readiness_health_check_interval)
      mapping[:readiness_health_check_http_endpoint] = params[:readiness_health_check_http_endpoint] if params.key?(:readiness_health_check_http_endpoint)
      mapping[:timeout] = params[:timeout] if params.key?(:timeout)
      mapping[:type] = params[:type]

      if params.key?(:health_check_type)
        mapping[:health_check_type] = converted_health_check_type(params[:health_check_type])
        mapping[:health_check_timeout] = params[:health_check_timeout] if params.key?(:health_check_timeout)
      end
      mapping[:readiness_health_check_type] = converted_health_check_type(params[:readiness_health_check_type]) if params.key?(:readiness_health_check_type)
      mapping
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def env_update_attribute_mapping
      mapping = {}
      mapping[:var] = env.transform_values(&:to_s) if requested?(:env) && env.is_a?(Hash)
      mapping
    end

    def routes_attribute_mapping
      mapping = {}
      mapping[:no_route] = no_route if requested?(:no_route)
      mapping[:routes] = routes if requested?(:routes)
      mapping[:random_route] = random_route if requested?(:random_route)
      mapping[:default_route] = default_route if requested?(:default_route)
      mapping
    end

    def service_bindings_attribute_mapping
      mapping = {}
      mapping[:services] = services if requested?(:services)
      mapping
    end

    def should_autodetect?(buildpack)
      buildpack == 'default' || buildpack == 'null' || buildpack.nil?
    end

    # 'none' was deprecated in favor of process
    def converted_health_check_type(health_check_type)
      HEALTH_CHECK_TYPE_MAPPING[health_check_type] || health_check_type
    end

    def convert_to_mb(human_readable_byte_value)
      byte_converter.convert_to_mb(human_readable_byte_value)
    rescue ByteConverter::InvalidUnitsError, ByteConverter::NonNumericError
    end

    def convert_to_bytes_per_second(human_readable_byte_value)
      human_readable_byte_value = human_readable_byte_value.to_s
      return nil if human_readable_byte_value.blank?
      return -1 if human_readable_byte_value.to_s == '-1'
      return 0 if human_readable_byte_value.to_s == '0'

      byte_converter.convert_to_b(human_readable_byte_value.strip)
    rescue ByteConverter::InvalidUnitsError, ByteConverter::NonNumericError
    end

    def validate_byte_format(human_readable_byte_value, attribute_name, allow_unlimited: false)
      byte_converter.convert_to_mb(human_readable_byte_value) unless allow_unlimited && ['-1', '0'].include?(human_readable_byte_value.to_s)

      nil
    rescue ByteConverter::InvalidUnitsError
      "#{attribute_name} must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB"
    rescue ByteConverter::NonNumericError
      "#{attribute_name} is not a number"
    end

    def byte_converter
      ByteConverter.new
    end

    def validate_manifest_process_scale_messages!
      validate_messages!(manifest_process_scale_messages)
    end

    def validate_manifest_process_update_messages!
      validate_messages!(manifest_process_update_messages)
    end

    def validate_messages!(messages)
      messages.each do |msg|
        msg.valid?
        msg.errors.full_messages.each do |error_message|
          add_process_error!(error_message, msg.type)
        end
      end
    end

    def validate_manifest_routes_update_message!
      manifest_routes_update_message.valid?
      manifest_routes_update_message.errors.full_messages.each do |error_message|
        errors.add(:base, error_message)
      end
    end

    def validate_app_update_message!
      app_update_message.valid?
      app_update_message.errors[:lifecycle].each do |error_message|
        if error_message.starts_with?('Buildpacks')
          errors.add(:base, error_message) if requested?(:buildpacks)
        else
          errors.add(:base, error_message)
        end
      end

      %i[command metadata].each do |error_type|
        app_update_message.errors[error_type].each do |error_message|
          errors.add(error_type, error_message)
        end
      end
    end

    def validate_manifest_singular_buildpack_message!
      manifest_buildpack_message.valid?
      manifest_buildpack_message.errors[:buildpack].each do |error_message|
        errors.add(:buildpack, error_message)
      end
    end

    def validate_env_update_message!
      app_update_environment_variables_message.valid?
      app_update_environment_variables_message.errors[:var].each do |error_message|
        if error_message == 'must be an object'
          errors.add(:base, message: 'Env must be an object of keys and values')
        else
          errors.add(:env, message: error_message)
        end
      end
    end

    def validate_service_bindings_message!
      manifest_service_bindings_message.valid?
      manifest_service_bindings_message.errors.full_messages.each do |error_message|
        errors.add(:base, error_message)
      end
    end

    def validate_processes!
      return errors.add(:base, 'Processes must be an array of process configurations') unless processes.is_a?(Array)

      errors.add(:base, 'All Processes must specify a type') if processes.any? { |p| p[:type].blank? }

      processes.group_by { |p| p[:type] }.
        select { |_, v| v.length > 1 }.
        each_key { |type| errors.add(:base, %(Process "#{type}" may only be present once)) }

      processes.each do |process|
        type = process[:type]
        memory_error = validate_byte_format(process[:memory], 'Memory')
        disk_error = validate_byte_format(process[:disk_quota], 'Disk quota')
        log_rate_limit_error = validate_byte_format(process[:log_rate_limit_per_second], 'Log rate limit per second', allow_unlimited: true)
        add_process_error!(memory_error, type) if memory_error
        add_process_error!(disk_error, type) if disk_error
        add_process_error!(log_rate_limit_error, type) if log_rate_limit_error
      end
    end

    def validate_sidecars!
      return errors.add(:base, 'Sidecars must be an array of sidecar configurations') unless sidecars.is_a?(Array)

      sidecar_create_messages.each do |sidecar_create_message|
        sidecar_create_message.validate
        sidecar_create_message.errors.full_messages.each do |message|
          error = sidecar_create_message.name.present? ? %("#{sidecar_create_message.name}": #{message}) : message.downcase
          errors.add(:sidecar, error)
        end
      end
    end

    def validate_top_level_web_process!
      memory_error = validate_byte_format(memory, 'Memory')
      disk_error = validate_byte_format(disk_quota, 'Disk quota')
      log_rate_limit_error = validate_byte_format(log_rate_limit_per_second, 'Log rate limit per second', allow_unlimited: true)
      add_process_error!(memory_error, ProcessTypes::WEB) if memory_error
      add_process_error!(disk_error, ProcessTypes::WEB) if disk_error
      add_process_error!(log_rate_limit_error, ProcessTypes::WEB) if log_rate_limit_error
    end

    def validate_buildpack_and_buildpacks_combination!
      return unless requested?(:buildpack) && requested?(:buildpacks)

      errors.add(:base, 'Buildpack and Buildpacks fields cannot be used together.')
    end

    def validate_docker_enabled!
      FeatureFlag.raise_unless_enabled!(:diego_docker) if requested?(:docker)
    rescue StandardError => e
      errors.add(:base, e.message)
    end

    def validate_cnb_enabled!
      FeatureFlag.raise_unless_enabled!(:diego_cnb) if requested?(:lifecycle) && @lifecycle == 'cnb'
    rescue StandardError => e
      errors.add(:base, e.message)
    end

    def validate_docker_buildpacks_combination!
      return unless requested?(:docker) && (requested?(:buildpack) || requested?(:buildpacks))

      errors.add(:base, 'Cannot specify both buildpack(s) and docker keys')
    end

    def add_process_error!(error_message, type)
      errors.add(:base, %(Process "#{type}": #{error_message}))
    end

    def requested_buildpacks
      return nil unless requested?(:buildpacks) || requested?(:buildpack)
      return @buildpacks if requested?(:buildpacks)

      buildpacks = []
      buildpacks.push(@buildpack) if requested?(:buildpack) && !should_autodetect?(@buildpack)

      buildpacks
    end
  end
end
