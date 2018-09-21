require 'messages/base_message'
require 'messages/manifest_process_scale_message'
require 'messages/manifest_process_update_message'
require 'messages/manifest_buildpack_message'
require 'messages/manifest_service_binding_create_message'
require 'messages/manifest_routes_update_message'
require 'cloud_controller/app_manifest/byte_converter'
require 'models/helpers/health_check_types'
require 'presenters/helpers/censorship'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    register_allowed_keys [
      :buildpack,
      :buildpacks,
      :command,
      :disk_quota,
      :env,
      :health_check_http_endpoint,
      :health_check_invocation_timeout,
      :health_check_timeout,
      :health_check_type,
      :timeout,
      :instances,
      :memory,
      :no_route,
      :processes,
      :random_route,
      :routes,
      :services,
      :stack,
    ]

    HEALTH_CHECK_TYPE_MAPPING = { HealthCheckTypes::NONE => HealthCheckTypes::PROCESS }.freeze

    def self.create_from_yml(parsed_yaml)
      AppManifestMessage.new(parsed_yaml, underscore_keys(parsed_yaml.deep_symbolize_keys))
    end

    def self.underscore_keys(hash)
      hash.inject({}) do |memo, (key, val)|
        new_key = key.to_s.underscore.to_sym
        memo[new_key] = if key == :processes && val.is_a?(Array)
                          val.map { |process| underscore_keys(process) }
                        else
                          val
                        end
        memo
      end
    end

    validate :validate_top_level_web_process!
    validate :validate_processes!, if: proc { |record| record.requested?(:processes) }
    validate :validate_manifest_process_scale_messages!
    validate :validate_manifest_process_update_messages!
    validate :validate_app_update_message!
    validate :validate_buildpack_and_buildpacks_combination!
    validate :validate_service_bindings_message!, if: proc { |record| record.requested?(:services) }
    validate :validate_env_update_message!, if: proc { |record| record.requested?(:env) }
    validate :validate_manifest_singular_buildpack_message!, if: proc { |record| record.requested?(:buildpack) }
    validate :validate_manifest_routes_update_message!, if: proc { |record|
      record.requested?(:routes) ||
      record.requested?(:no_route) ||
      record.requested?(:random_route)
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

    def app_update_message
      @app_update_message ||= AppUpdateMessage.new(app_update_attribute_mapping)
    end

    def app_update_environment_variables_message
      @app_update_environment_variables_message ||= AppUpdateEnvironmentVariablesMessage.new(env_update_attribute_mapping)
    end

    def manifest_service_bindings_message
      @manifest_service_bindings_message ||= ManifestServiceBindingCreateMessage.new(service_bindings_attribute_mapping)
    end

    def manifest_routes_update_message
      @manifest_routes_update_message ||= ManifestRoutesUpdateMessage.new(routes_attribute_mapping)
    end

    def audit_hash
      overrides = original_yaml['env'] ? { 'env' => Presenters::Censorship::PRIVATE_DATA_HIDDEN } : {}
      original_yaml.merge(overrides)
    end

    private

    attr_reader :original_yaml

    def manifest_buildpack_message
      @manifest_buildpack_message ||= ManifestBuildpackMessage.new(buildpack: buildpack)
    end

    def process_scale_attribute_mappings
      process_scale_attributes_from_app_level = process_scale_attributes(memory: memory, disk_quota: disk_quota, instances: instances)

      process_attributes(process_scale_attributes_from_app_level) do |process|
        process_scale_attributes(
          memory: process[:memory],
          disk_quota: process[:disk_quota],
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

    def process_scale_attributes(memory:, disk_quota:, instances:, type: nil)
      memory_in_mb = convert_to_mb(memory)
      disk_in_mb = convert_to_mb(disk_quota)
      {
        instances: instances,
        memory: memory_in_mb,
        disk_quota: disk_in_mb,
        type: type
      }.compact
    end

    def process_update_attributes_from_app_level
      mapping = {}
      mapping[:command] = command || 'null' if requested?(:command)
      mapping[:health_check_http_endpoint] = health_check_http_endpoint if requested?(:health_check_http_endpoint)
      mapping[:timeout] = timeout if requested?(:timeout)
      mapping[:health_check_invocation_timeout] = health_check_invocation_timeout if requested?(:health_check_invocation_timeout)

      if requested?(:health_check_type)
        mapping[:health_check_type] = converted_health_check_type(health_check_type)
        mapping[:health_check_http_endpoint] ||= '/' if health_check_type == HealthCheckTypes::HTTP
      end
      mapping
    end

    def process_update_attributes_from_process(params)
      mapping = {}
      mapping[:command] = params[:command] || 'null' if params.key?(:command)
      mapping[:health_check_http_endpoint] = params[:health_check_http_endpoint] if params.key?(:health_check_http_endpoint)
      mapping[:health_check_timeout] = params[:health_check_timeout] if params.key?(:health_check_timeout)
      mapping[:health_check_invocation_timeout] = params[:health_check_invocation_timeout] if params.key?(:health_check_invocation_timeout)
      mapping[:timeout] = params[:timeout] if params.key?(:timeout)
      mapping[:type] = params[:type]

      if params.key?(:health_check_type)
        mapping[:health_check_type] = converted_health_check_type(params[:health_check_type])
        mapping[:health_check_http_endpoint] ||= '/' if params[:health_check_type] == HealthCheckTypes::HTTP
        mapping[:health_check_timeout] = params[:health_check_timeout] if params.key?(:health_check_timeout)
      end
      mapping
    end

    def app_update_attribute_mapping
      mapping = {
        lifecycle: buildpacks_lifecycle_data
      }.compact
      mapping
    end

    def env_update_attribute_mapping
      mapping = {}
      if requested?(:env) && env.is_a?(Hash)
        mapping[:var] = env.transform_values(&:to_s)
      end
      mapping
    end

    def routes_attribute_mapping
      mapping = {}
      mapping[:routes] = routes if requested?(:routes)
      mapping[:no_route] = no_route if requested?(:no_route)
      mapping[:random_route] = random_route if requested?(:random_route)
      mapping
    end

    def service_bindings_attribute_mapping
      mapping = {}
      mapping[:services] = services if requested?(:services)
      mapping
    end

    def buildpacks_lifecycle_data
      return unless requested?(:buildpacks) || requested?(:buildpack) || requested?(:stack)

      if requested?(:buildpacks)
        requested_buildpacks = @buildpacks
      elsif requested?(:buildpack)
        requested_buildpacks = []
        requested_buildpacks.push(@buildpack) unless should_autodetect?(@buildpack)
      end

      {
        type: Lifecycles::BUILDPACK,
        data: {
          buildpacks: requested_buildpacks,
          stack: @stack
        }.compact
      }
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

    def validate_byte_format(human_readable_byte_value, attribute_name)
      byte_converter.convert_to_mb(human_readable_byte_value)

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

      app_update_message.errors[:command].each do |error_message|
        errors.add(:command, error_message)
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
        if error_message == 'must be a hash'
          errors[:base] << 'Env must be a hash of keys and values'
        else
          errors[:env] << error_message
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
      unless processes.is_a?(Array)
        return errors.add(:base, 'Processes must be an array of process configurations')
      end

      errors.add(:base, 'All Processes must specify a type') if processes.any? { |p| p[:type].blank? }

      processes.group_by { |p| p[:type] }.
        select { |_, v| v.length > 1 }.
        each_key { |type| errors.add(:base, %(Process "#{type}" may only be present once)) }

      processes.each do |process|
        type = process[:type]
        memory_error = validate_byte_format(process[:memory], 'Memory')
        disk_error = validate_byte_format(process[:disk_quota], 'Disk quota')
        add_process_error!(memory_error, type) if memory_error
        add_process_error!(disk_error, type) if disk_error
      end
    end

    def validate_top_level_web_process!
      memory_error = validate_byte_format(memory, 'Memory')
      disk_error = validate_byte_format(disk_quota, 'Disk quota')
      add_process_error!(memory_error, 'web') if memory_error
      add_process_error!(disk_error, 'web') if disk_error
    end

    def validate_buildpack_and_buildpacks_combination!
      if requested?(:buildpack) && requested?(:buildpacks)
        errors.add(:base, 'Buildpack and Buildpacks fields cannot be used together.')
      end
    end

    def add_process_error!(error_message, type)
      errors.add(:base, %(Process "#{type}": #{error_message}))
    end
  end
end
