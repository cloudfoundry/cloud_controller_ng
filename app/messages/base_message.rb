require 'active_model'
require 'messages/validators'

module VCAP::CloudController
  class BaseMessage
    include ActiveModel::Model
    include Validators

    attr_accessor :requested_keys, :extra_keys

    class NoAdditionalKeysValidator < ActiveModel::Validator
      def validate(record)
        if record.extra_keys.any?
          record.errors[:base] << "#{record.error_message} '#{record.extra_keys.join("', '")}'"
        end
      end
    end

    validates_with NoAdditionalKeysValidator

    def initialize(params={})
      @requested_keys   = params.keys
      disallowed_params = params.slice!(*allowed_keys)
      @extra_keys       = disallowed_params.keys
      super(params)
    end

    def requested?(key)
      requested_keys.include?(key)
    end

    def audit_hash
      request = {}
      requested_keys.each do |key|
        request[key.to_s] = self.try(key)
      end
      request
    end

    def error_message
      'Unknown field(s):'
    end

    private

    def allowed_keys
      raise NotImplementedError
    end
  end
end
