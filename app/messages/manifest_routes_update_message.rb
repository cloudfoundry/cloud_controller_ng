require 'messages/base_message'
require 'messages/route_options_message'
require 'cloud_controller/app_manifest/manifest_route'

module VCAP::CloudController
  class ManifestRoutesUpdateMessage < BaseMessage
    register_allowed_keys %i[routes no_route random_route default_route]

    class ManifestRoutesYAMLValidator < ActiveModel::Validator
      def validate(record)
        if is_not_array?(record.routes) || contains_non_route_hash_values?(record.routes)
          record.errors.add(:routes, message: 'must be a list of route objects')
          return
        end

        if contains_invalid_route_options?(record.routes)
          record.errors.add(:routes, message: 'contains invalid route options')
          return
        end

        return unless contains_invalid_lb_algo?(record.routes)

        record.errors.add(:routes, message: 'contains an invalid loadbalancing-algorithm option')
        nil
      end

      def is_not_array?(routes)
        !routes.is_a?(Array)
      end

      def contains_non_route_hash_values?(routes)
        routes.any? { |r| !(r.is_a?(Hash) && r[:route].present?) }
      end

      def contains_invalid_route_options?(routes)
        routes.any? do |r|
          next unless r[:options]

          return true unless r[:options].is_a?(Hash)

          return false if r[:options].empty?

          return r[:options].keys.all? { |key| RouteOptionsMessage::VALID_MANIFEST_ROUTE_OPTIONS.exclude?(key) }
        end
      end

      def contains_invalid_lb_algo?(routes)
        routes.any? do |r|
          next unless r[:options] && r[:options][:'loadbalancing-algorithm']

          return true if r[:options][:'loadbalancing-algorithm'] && RouteOptionsMessage::VALID_LOADBALANCING_ALGORITHMS.exclude?(r[:options][:'loadbalancing-algorithm'])
        end
      end
    end

    validates_with NoAdditionalKeysValidator
    validates_with ManifestRoutesYAMLValidator, if: proc { |record| record.requested?(:routes) }
    validate :routes_are_uris, if: proc { |record| record.requested?(:routes) }
    validate :route_protocols_are_valid, if: proc { |record| record.requested?(:routes) }
    validate :no_route_is_boolean
    validate :default_route_is_boolean
    validate :random_route_is_boolean
    validate :random_route_and_default_route_conflict

    def manifest_route_mappings
      @manifest_route_mappings ||= routes.map do |route|
        r = {
          route: ManifestRoute.parse(route[:route], route[:options]),
          protocol: route[:protocol]
        }
        r[:options] = route[:options] unless route[:options].nil?
        r
      end
    end

    private

    def routes_are_uris
      return if errors[:routes].present?

      manifest_route_mappings.each do |manifest_route_mapping|
        next if manifest_route_mapping[:route].valid?

        errors.add(:base, "The route '#{manifest_route_mapping[:route]}' is not a properly formed URL")
      end
    end

    def route_protocols_are_valid
      return if errors[:routes].present?

      manifest_route_mappings.each do |manifest_route_mapping|
        next if manifest_route_mapping[:protocol].nil? || RouteMappingModel::VALID_PROTOCOLS.include?(manifest_route_mapping[:protocol])

        errors.add(:base, "Route protocol must be 'http1', 'http2' or 'tcp'.")
      end
    end

    def default_route_is_boolean
      is_boolean(default_route, field_name: 'Default-route')
    end

    def no_route_is_boolean
      is_boolean(no_route, field_name: 'No-route')
    end

    def random_route_is_boolean
      is_boolean(random_route, field_name: 'Random-route')
    end

    def is_boolean(field, field_name:)
      return if field.nil?

      return if [true, false].include?(field)

      errors.add(:base, "#{field_name} must be a boolean")
    end

    def random_route_and_default_route_conflict
      errors.add(:base, 'Random-route and default-route may not be used together') if random_route && default_route
    end
  end
end
