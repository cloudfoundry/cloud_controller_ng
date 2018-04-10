require 'messages/base_message'

module VCAP::CloudController
  class ManifestRoutesMessage < BaseMessage
    ALLOWED_KEYS = [:routes].freeze
    VALID_URI_REGEX = Regexp.new('^(?:https?://|tcp://)?(?:(?:[\\w-]+\\.)|(?:[*]\\.))+\\w+(?:\\:\\d+)?(?:/.*)*(?:\\.\\w+)?$')

    attr_accessor(*ALLOWED_KEYS)

    class ManifestRoutesValidator < ActiveModel::Validator
      def validate(record)
        if !record.routes.is_a?(Array)
          record.errors[:routes] << 'Routes must be a list of routes'
        else
          record.routes.each do |route_hash|
            route_uri = route_hash[:route]
            unless VALID_URI_REGEX.match?(route_uri)
              record.errors[:routes] << "The route '#{route_uri}' is not a properly formed URL"
            end
          end
        end
      end
    end

    validates_with NoAdditionalKeysValidator
    validates_with ManifestRoutesValidator

    def self.create_from_http_request(body)
      ManifestRoutesMessage.new(body.deep_symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
