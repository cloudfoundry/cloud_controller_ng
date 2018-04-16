require 'messages/base_message'
require 'cloud_controller/app_manifest/manifest_route'

module VCAP::CloudController
  class ManifestRoutesUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:routes].freeze

    attr_accessor(*ALLOWED_KEYS)

    class ManifestRoutesYAMLValidator < ActiveModel::Validator
      def validate(record)
        if is_not_array?(record.routes) || contains_non_hash_values?(record.routes)
          record.errors[:routes] << 'must be a list of route hashes'
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
    validates_with ManifestRoutesYAMLValidator
    validate :routes_are_uris

    def self.create_from_http_request(body)
      ManifestRoutesUpdateMessage.new(body.deep_symbolize_keys)
    end

    def route_hashes
      manifest_routes.map(&:to_hash)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end

    def manifest_routes
      @manifest_routes ||= routes.map { |route| ManifestRoute.parse(route[:route]) }
    end

    def routes_are_uris
      return if errors[:routes].present?

      manifest_routes.each do |manifest_route|
        next if manifest_route.valid?
        errors.add(:base, "The route '#{manifest_route}' is not a properly formed URL")
      end
    end
  end
end
