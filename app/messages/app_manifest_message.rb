require 'messages/base_message'
require 'messages/manifest_process_scale_message'
require 'cloud_controller/app_manifest/byte_converter'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    ALLOWED_KEYS = [:buildpack, :command, :disk_quota, :env, :instances,
                    :memory, :stack].freeze

    attr_accessor(*ALLOWED_KEYS)
    attr_accessor :manifest_process_scale_message, :app_update_message, :manifest_env_update_message

    validates_with NoAdditionalKeysValidator

    def self.create_from_http_request(parsed_yaml)
      AppManifestMessage.new(parsed_yaml.deep_symbolize_keys)
    end

    def initialize(params)
      super(params)
      @manifest_process_scale_message = ManifestProcessScaleMessage.new(process_scale_attribute_mapping)
      @app_update_message = AppUpdateMessage.create_from_http_request(app_update_attribute_mapping)
      @manifest_env_update_message = AppUpdateEnvironmentVariablesMessage.create_from_http_request(env_update_attribute_mapping)
    end

    def valid?
      validate_process_scale_message!
      validate_app_update_message!
      validate_env_update_message! if requested?(:env)

      errors.empty?
    end

    def process_scale_message
      return @process_scale_message if @process_scale_message.present?

      process_scale_message_params = {
        instances: manifest_process_scale_message.instances,
        disk_in_mb: manifest_process_scale_message.disk_quota,
        memory_in_mb: manifest_process_scale_message.memory
      }.compact

      @process_scale_message = ProcessScaleMessage.new(process_scale_message_params)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end

    def process_scale_attribute_mapping
      {
        instances: instances,
        memory: convert_to_mb(memory, 'Memory'),
        disk_quota: convert_to_mb(disk_quota, 'Disk quota'),
      }.compact
    end

    def app_update_attribute_mapping
      mapping = {
        lifecycle: buildpack_lifecycle_data
      }.compact
      if requested?(:command)
        actual_command = (command == 'default' || command == 'null') ? nil : command
        mapping[:command] = actual_command
      end
      mapping
    end

    def env_update_attribute_mapping
      mapping = {}
      if requested?(:env)
        mapping[:var] = env
      end
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

    def convert_to_mb(human_readable_byte_value, attribute)
      byte_converter.convert_to_mb(human_readable_byte_value)
    rescue ByteConverter::InvalidUnitsError
      errors.add(:base, "#{attribute} must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB")

      nil
    rescue ByteConverter::NonNumericError
      errors.add(:base, "#{attribute} is not a number")
      nil
    end

    def byte_converter
      ByteConverter.new
    end

    def validate_process_scale_message!
      manifest_process_scale_message.valid?
      manifest_process_scale_message.errors.full_messages.each do |error_message|
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
      manifest_env_update_message.valid?
      manifest_env_update_message.errors[:var].each do |error_message|
        if error_message == 'must be a hash'
          errors[:base] << 'env must be a hash of keys and values'
        else
          errors[:env] << error_message
        end
      end
    end
  end
end
