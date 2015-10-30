require 'messages/base_message'
require 'messages/buildpack_lifecycle_data_message'

module VCAP::CloudController
  class AppUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :environment_variables, :lifecycle]

    attr_accessor(*ALLOWED_KEYS)
    attr_reader :app

    validates_with NoAdditionalKeysValidator, LifecycleDataValidator
    BUILDPACK_LIFECYCLE = 'buildpack'
    LIFECYCLE_TYPES = [BUILDPACK_LIFECYCLE].map(&:freeze).freeze

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    validates :name, string: true, allow_nil: true
    validates :environment_variables, hash: true, allow_nil: true

    validates :lifecycle_type,
      presence: true,
      if: lifecycle_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

    def requested_buildpack?
      requested?(:lifecycle) && lifecycle_type == BUILDPACK_LIFECYCLE
    end

    def data_validation_config
      OpenStruct.new(
        data_class: 'BuildpackLifecycleDataMessage',
        skip_validation: !lifecycle,
        allow_nil: false,
        data: lifecycle_data,
      )
    end

    def self.create_from_http_request(body)
      AppUpdateMessage.new(body.symbolize_keys)
    end

    delegate :buildpack, to: :buildpack_data

    def buildpack_data
      @buildpack_data ||= BuildpackLifecycleDataMessage.new((lifecycle_data || {}).symbolize_keys)
    end

    def lifecycle_type
      return if lifecycle.nil?
      lifecycle['type'] || lifecycle[:type]
    end

    def lifecycle_data
      return if lifecycle.nil?
      lifecycle['data'] || lifecycle[:data]
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
