require 'messages/metadata_base_message'
require 'messages/route_options_message'

module VCAP::CloudController
  class RouteUpdateMessage < MetadataBaseMessage
    register_allowed_keys %i[options]

    def self.options_requested?
      @options_requested ||= proc { |a| a.requested?(:options) }
    end

    def options_message
      @options_message ||= RouteOptionsMessage.new(options&.deep_symbolize_keys)
    end

    validates_with OptionsValidator, if: options_requested?

    validates_with NoAdditionalKeysValidator
  end
end
