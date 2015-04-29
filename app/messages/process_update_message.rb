require 'active_model'

module VCAP::CloudController
  class ProcessUpdateMessage
    include ActiveModel::Model

    class StringValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.errors.add attribute, 'must be a string' unless value.is_a?(String)
      end
    end

    class GuidValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.errors.add attribute, 'must be a string' unless value.is_a?(String)
        record.errors.add attribute, 'must be between 1 and 200 characters' unless value.is_a?(String) && (1..200).include?(value.size)
      end
    end

    class NoAdditionalKeysValidator < ActiveModel::Validator
      def validate(record)
        if record.extra_keys.any?
          record.errors[:base] << "Unknown field(s): '#{record.extra_keys.join("', '")}'"
        end
      end
    end

    validates_with NoAdditionalKeysValidator

    attr_accessor :guid, :command
    attr_accessor :requested_keys, :extra_keys

    validates :guid, guid: true
    validates :command,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:command) }

    def initialize(params)
      @requested_keys   = params.keys
      disallowed_params = params.slice!(*allowed_keys)
      @extra_keys       = disallowed_params.keys

      super(params)
    end

    def self.create_from_http_request(guid, body)
      ProcessUpdateMessage.new(body.symbolize_keys.merge(guid: guid))
    end

    def requested?(key)
      requested_keys.include?(key)
    end

    def allowed_keys
      [:guid, :command]
    end
  end
end
