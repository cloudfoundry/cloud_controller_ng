require 'messages/base_message'
require 'messages/buildpack_lifecycle_data_message'

module VCAP::CloudController
  class AppCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :environment_variables, :relationships, :lifecycle]

    attr_accessor(*ALLOWED_KEYS)

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    validates_with NoAdditionalKeysValidator, RelationshipValidator
    validates_with LifecycleValidator, if: lifecycle_requested?

    validates :name, string: true
    validates :environment_variables, hash: true, allow_nil: true
    validates :relationships, hash: true, allow_nil: false

    validates :lifecycle_type,
      string: true,
      if: lifecycle_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

    def space_guid
      relationships.try(:[], 'space').try(:[], 'guid') ||
        relationships.try(:[], :space).try(:[], :guid)
    end

    class Relationships < BaseMessage
      attr_accessor :space

      def allowed_keys
        [:space]
      end

      validates_with NoAdditionalKeysValidator

      validates :space, presence: true, allow_nil: false, to_one_relationship: true
    end

    delegate :buildpack, :stack, to: :buildpack_data

    def self.create_from_http_request(body)
      AppCreateMessage.new(body.symbolize_keys)
    end

    def buildpack_data
      @buildpack_data ||= BuildpackLifecycleDataMessage.new((lifecycle_data || {}).symbolize_keys)
    end

    def lifecycle_type
      lifecycle.try(:[], 'type') || lifecycle.try(:[], :type)
    end

    def lifecycle_data
      lifecycle.try(:[], 'data') || lifecycle.try(:[], :data)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
