require 'messages/base_message'
require 'messages/processes/process_scale_message'
require 'palm_civet'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    ALLOWED_KEYS = [:instances, :memory].freeze

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
      @process_scale_message ||= ProcessScaleMessage.create_from_http_request(process_scale_data)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end

    def process_scale_data
      {
        instances: instances,
        memory_in_mb: convert_memory_to_mb(memory)
      }
    end

    def convert_memory_to_mb(memory)
      memory_in_mb = PalmCivet.to_megabytes(memory) if memory
    rescue PalmCivet::InvalidByteQuantityError => e
      errors.add(:base, 'memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB')

      memory_in_mb
    end
  end
end
