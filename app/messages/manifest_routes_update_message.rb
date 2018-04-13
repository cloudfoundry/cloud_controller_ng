require 'messages/base_message'

module VCAP::CloudController
  class ManifestRoutesUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:routes].freeze
    VALID_URI_REGEX = Regexp.new('^(?:https?://|tcp://)?(?:(?:[\\w-]+\\.)|(?:[*]\\.))+\\w+(?:\\:\\d+)?(?:/.*)*(?:\\.\\w+)?$')

    attr_accessor(*ALLOWED_KEYS)

    class ManifestRoutesValidator < ActiveModel::Validator
      def validate(record)
        if is_not_array?(record.routes) || contains_non_hash_values?(record.routes)
          record.errors[:base] << 'routes must be a list of route hashes'
        else
          record.routes.each do |route_hash|
            route_uri = route_hash[:route]
            unless VALID_URI_REGEX.match?(route_uri)
              record.errors[:base] << "The route '#{route_uri}' is not a properly formed URL"
            end
          end
        end
      end

      def is_not_array?(routes)
        !routes.is_a?(Array)
      end

      def contains_non_hash_values?(routes)
        routes.any? {|r| !r.is_a?(Hash)}
      end
    end

    validates_with NoAdditionalKeysValidator
    validates_with ManifestRoutesValidator

    def self.create_from_http_request(body)
      ManifestRoutesUpdateMessage.new(body.deep_symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
