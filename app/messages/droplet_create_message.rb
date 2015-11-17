require 'messages/base_message'
require 'messages/validators'

module VCAP::CloudController
  class DropletCreateMessage < BaseMessage
    ALLOWED_KEYS = [:memory_limit, :disk_limit, :environment_variables, :lifecycle]

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator, LifecycleDataValidator
    BUILDPACK_LIFECYCLE = 'buildpack'
    LIFECYCLE_TYPES = [BUILDPACK_LIFECYCLE].map(&:freeze).freeze

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    validates :memory_limit, numericality: { only_integer: true }, allow_nil: true
    validates :disk_limit, numericality: { only_integer: true }, allow_nil: true
    validates :environment_variables, environment_variables: true, allow_nil: true

    validates :lifecycle_type,
      presence: true,
      inclusion: { in: LIFECYCLE_TYPES },
      if: lifecycle_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

    def self.create_from_http_request(body)
      DropletCreateMessage.new(body.symbolize_keys)
    end

    def data_validation_config
      OpenStruct.new(
        data_class: 'BuildpackLifecycleDataMessage',
        allow_nil: false,
        data: lifecycle_data,
      )
    end

    def lifecycle_data
      lifecycle['data'] || lifecycle[:data]
    end

    def lifecycle_type
      lifecycle['type'] || lifecycle[:type]
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
