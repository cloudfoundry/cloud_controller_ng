require 'messages/base_message'
require 'messages/manifest_process_scale_message'
require 'cloud_controller/app_manifest/byte_converter'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    ALLOWED_KEYS = [:instances, :memory, :disk_quota, :buildpack].freeze

    attr_accessor(*ALLOWED_KEYS)
    attr_accessor :manifest_process_scale_message, :app_update_message

    validates_with NoAdditionalKeysValidator

    def self.create_from_http_request(parsed_yaml)
      AppManifestMessage.new(parsed_yaml.deep_symbolize_keys)
    end

    def initialize(params)
      super(params)
      @manifest_process_scale_message = ManifestProcessScaleMessage.new(process_scale_attribute_mapping)
      @app_update_message = AppUpdateMessage.create_from_http_request(app_update_attribute_mapping)
    end

    def valid?
      manifest_process_scale_message.valid?
      manifest_process_scale_message.errors.full_messages.each do |error_message|
        errors.add(:base, error_message)
      end

      app_update_message.valid?
      app_update_message.errors.full_messages.each do |error_message|
        errors.add(:base, error_message)
      end

      if errors.empty? && buildpack_validator
        buildpack_validator.valid?
        buildpack_validator.errors.full_messages.each do |error_message|
          errors.add(:base, error_message)
        end
      end
      errors.empty?
    end

    def process_scale_message
      # convert self's ManifestProcessScaleMessage into a ProcessScaleMessage
      @process_scale_message ||= begin
        params = {}
        [[:instances, :instances],
         [:disk_quota, :disk_in_mb],
         [:memory, :memory_in_mb]].each do |original_key, target_key|
          params[target_key] = manifest_process_scale_message.send(original_key) if manifest_process_scale_message.requested?(original_key)
        end
        ProcessScaleMessage.new(params)
      end
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end

    def buildpack_validator
      @buildpack_validator ||= begin
        buildpacks = app_update_message.try(:buildpack_data).try(:buildpacks)
        if buildpacks
          db_result = BuildpackLifecycleFetcher.fetch(buildpacks, Stack.last.try(:name))
          BuildpackLifecycleDataValidator.new({
            buildpack_infos: db_result[:buildpack_infos],
            stack: db_result[:stack],
          })
        end
      end
    end

    def process_scale_attribute_mapping
      {
        instances: instances,
        memory: convert_to_mb(memory, 'Memory'),
        disk_quota: convert_to_mb(disk_quota, 'Disk quota'),
      }.compact
    end

    def app_update_attribute_mapping
      {
        lifecycle: buildpack_lifecycle_data,

      }.compact
    end

    def buildpack_lifecycle_data
      return unless requested?(:buildpack)

      {
        type: Lifecycles::BUILDPACK,
        data: {
          buildpacks: [buildpack].reject { |x| x == 'default' }.compact
        }
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
  end
end
