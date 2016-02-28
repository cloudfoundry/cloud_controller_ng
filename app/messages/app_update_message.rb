require 'messages/base_message'
require 'messages/lifecycles/buildpack_lifecycle_data_message'

module VCAP::CloudController
  class AppUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :environment_variables, :lifecycle].freeze

    attr_accessor(*ALLOWED_KEYS)
    attr_reader :app

    def self.create_from_http_request(body)
      AppUpdateMessage.new(body.symbolize_keys)
    end

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with LifecycleValidator, if: lifecycle_requested?

    validates :name, string: true, allow_nil: true
    validates :environment_variables, hash: true, allow_nil: true

    validates :lifecycle_type,
      string: true,
      allow_nil: false,
      if: lifecycle_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

    def lifecycle_data
      lifecycle.try(:[], 'data') || lifecycle.try(:[], :data)
    end

    def lifecycle_type
      lifecycle.try(:[], 'type') || lifecycle.try(:[], :type)
    end

    def buildpack_data
      @buildpack_data ||= BuildpackLifecycleDataMessage.create_from_http_request(lifecycle_data)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
