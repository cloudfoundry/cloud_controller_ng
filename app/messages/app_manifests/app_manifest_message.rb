require 'messages/base_message'
require 'messages/processes/process_scale_message'

module VCAP::CloudController
  class AppManifestMessage < BaseMessage
    ALLOWED_KEYS = [:instances].freeze

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
        instances: instances
      }
    end
  end
end
