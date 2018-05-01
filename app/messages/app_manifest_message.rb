require 'messages/base_message'
require 'messages/manifest_process_scale_message'
require 'messages/manifest_process_update_message'
require 'messages/manifest_service_binding_create_message'
require 'messages/manifest_routes_update_message'
require 'cloud_controller/app_manifest/byte_converter'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    register_allowed_keys [
      :buildpack,
      :command,
      :disk_quota,
      :env,
      :health_check_http_endpoint,
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

    HEALTH_CHECK_TYPE_MAPPING = { 'none' => 'process' }.freeze

    attr_accessor :manifest_process_scale_messages,
                  :manifest_process_update_messages,
                  :app_update_message,
                  :app_update_environment_variables_message,
                  :manifest_service_bindings_message,
                  :manifest_routes_update_message

    def self.create_from_yml(parsed_yaml)
      AppManifestMessage.new(underscore_keys(parsed_yaml.deep_symbolize_keys))
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

    def initialize(params)
      super(params)
      @manifest_process_scale_messages = process_scale_attribute_mappings.map { |mapping| ManifestProcessScaleMessage.new(mapping) }
      @manifest_process_update_messages = process_update_attribute_mappings.map { |mapping| ManifestProcessUpdateMessage.new(mapping) }
      @app_update_message = AppUpdateMessage.new(app_update_attribute_mapping)
      @app_update_environment_variables_message = AppUpdateEnvironmentVariablesMessage.new(env_update_attribute_mapping)
      @manifest_service_bindings_message = ManifestServiceBindingCreateMessage.new(service_bindings_attribute_mapping)
      @manifest_routes_update_message = ManifestRoutesUpdateMessage.new(routes_attribute_mapping)
    end

    def valid?
      validate_processes! if requested?(:processes)

      validate_manifest_process_scale_message!
      validate_manifest_process_update_message!
      validate_app_update_message!
      validate_manifest_routes_update_message! if requested?(:routes) || requested?(:no_route) || requested?(:random_route)
      validate_service_bindings_message! if requested?(:services)
      validate_env_update_message! if requested?(:env)

      errors.empty?
    end

    private

    def process_scale_attribute_mappings
      process_attributes(process_scale_attributes_from_app_level) do |process|
        process_scale_attributes_from_process(process)
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

    def process_scale_attributes_from_app_level
      memory_in_mb, memory_error = convert_to_mb(memory, 'Memory')
      disk_in_mb, disk_error = convert_to_mb(disk_quota, 'Disk quota')
      add_process_error!(memory_error, 'web') if memory_error
      add_process_error!(disk_error, 'web') if disk_error
      {
        instances: instances,
        memory: memory_in_mb,
        disk_quota: disk_in_mb,
      }.compact
    end

    def process_scale_attributes_from_process(process)
      type = process[:type]
      memory_in_mb, memory_error = convert_to_mb(process[:memory], 'Memory')
      disk_in_mb, disk_error = convert_to_mb(process[:disk_quota], 'Disk quota')
      add_process_error!(memory_error, type) if memory_error
      add_process_error!(disk_error, type) if disk_error
      {
        instances: process[:instances],
        memory: memory_in_mb,
        disk_quota: disk_in_mb,
        type: type
      }.compact
    end

    def add_process_error!(memory_error, type)
      errors.add(:base, %(Process "#{type}": #{memory_error}))
    end

    def process_update_attributes_from_app_level
      mapping = {}
      mapping[:command] = command || 'null' if requested?(:command)
      mapping[:health_check_http_endpoint] = health_check_http_endpoint if requested?(:health_check_http_endpoint)
      mapping[:timeout] = timeout if requested?(:timeout)

      if requested?(:health_check_type)
        mapping[:health_check_type] = converted_health_check_type(health_check_type)
        mapping[:health_check_http_endpoint] ||= '/' if health_check_type == 'http'
      end
      mapping
    end

    def process_update_attributes_from_process(params)
      mapping = {}
      mapping[:command] = params[:command] || 'null' if params.key?(:command)
      mapping[:health_check_http_endpoint] = params[:health_check_http_endpoint] if params.key?(:health_check_http_endpoint)
      mapping[:timeout] = params[:timeout] if params.key?(:timeout)
      mapping[:type] = params[:type]

      if params.key?(:health_check_type)
        mapping[:health_check_type] = converted_health_check_type(params[:health_check_type])
        mapping[:health_check_http_endpoint] ||= '/' if params[:health_check_type] == 'http'
      end
      mapping
    end

    def app_update_attribute_mapping
      mapping = {
        lifecycle: buildpack_lifecycle_data
      }.compact
      mapping
    end

    def env_update_attribute_mapping
      mapping = {}
      if requested?(:env) && env.is_a?(Hash)
        mapping[:var] = env.each { |k, v| env[k] = v.to_s }
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

    def buildpack_lifecycle_data
      return unless requested?(:buildpack) || requested?(:stack)

      buildpacks = [buildpack].reject { |x| x == 'default' }.compact if requested?(:buildpack)

      {
        type: Lifecycles::BUILDPACK,
        data: {
          buildpacks: buildpacks,
          stack: stack
        }.compact
      }
    end

    # none was deprecated in favor of process
    def converted_health_check_type(health_check_type)
      HEALTH_CHECK_TYPE_MAPPING[health_check_type] || health_check_type
    end

    def convert_to_mb(human_readable_byte_value, attribute)
      return byte_converter.convert_to_mb(human_readable_byte_value), nil
    rescue ByteConverter::InvalidUnitsError
      return nil, "#{attribute} must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB"
    rescue ByteConverter::NonNumericError
      return nil, "#{attribute} is not a number"
    end

    def byte_converter
      ByteConverter.new
    end

    def validate_manifest_process_scale_message!
      validate_messages!(manifest_process_scale_messages)
    end

    def validate_manifest_process_update_message!
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
        errors.add(:base, error_message)
      end
      app_update_message.errors[:command].each do |error_message|
        errors.add(:command, error_message)
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
      if processes.is_a? Array
        errors.add(:base, 'All Processes must specify a type') if processes.one? { |p| p[:type].blank? }

        processes.group_by { |p| p[:type] }.
          select { |k, v| v.length > 1 }.
          each_key { |k| errors.add(:base, %(Process "#{k}" may only be present once)) }

      else
        errors.add(:base, 'Processes must be an array of process configurations')
      end
    end
  end
end
