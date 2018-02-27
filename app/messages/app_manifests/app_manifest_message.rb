require 'messages/base_message'
require 'messages/processes/process_scale_message'
require 'cloud_controller/app_manifest/byte_converter'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    ALLOWED_KEYS = [:instances, :memory, :disk_quota].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(parsed_yaml)
      AppManifestMessage.new(parsed_yaml.deep_symbolize_keys)
    end

    def valid?
      process_scale_message.valid?
      process_scale_message.errors.full_messages.each do |error_message|
        errors.add(:base, error_message)
      end
      errors.empty?
    end

    def process_scale_message
      @process_scale_message ||= ProcessScaleMessage.create_from_http_request(process_scale_attribute_mapping)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end

    def process_scale_attribute_mapping
      {
        instances: instances,
        memory_in_mb: convert_to_mb(memory, 'Memory'),
        disk_in_mb: convert_to_mb(disk_quota, 'Disk Quota'),
      }.compact
    end

    def convert_to_mb(human_readable_byte_value, attribute)
      byte_converter.convert_to_mb(human_readable_byte_value)
    rescue ByteConverter::InvalidUnitsError
      errors.add(:base, "#{attribute} must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB")

      nil
    end

    def byte_converter
      ByteConverter.new
    end
  end
end
