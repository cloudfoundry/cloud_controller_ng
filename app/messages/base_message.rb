require 'active_model'
require 'messages/validators'

module VCAP::CloudController
  class BaseMessage
    include ActiveModel::Model
    include Validators

    attr_accessor :requested_keys, :extra_keys

    def self.register_allowed_keys(allowed_keys)
      self.const_set(:ALLOWED_KEYS, allowed_keys.freeze)
      attr_accessor(*allowed_keys)
    end

    def initialize(params)
      params = params ? params.to_unsafe_hash : {}
      @requested_keys   = params.keys
      disallowed_params = params.slice!(*allowed_keys)
      @extra_keys       = disallowed_params.keys
      super(params)
    end

    def requested?(key)
      requested_keys.include?(key)
    end

    def audit_hash(exclude: [])
      request = {}

      requested_keys.reduce(request) do |memo, key|
        memo[key] = self.try(key) unless exclude.include?(key)
        memo
      end

      request.deep_stringify_keys
    end

    def to_param_hash(opts={ exclude: [] })
      params = {}
      (requested_keys - opts[:exclude]).each do |key|
        val = self.try(key)
        params[key] = val.is_a?(Array) ? val.map { |v| v.gsub(',', CGI.escape(',')) }.join(',') : val
      end
      params
    end

    def self.to_array!(params, key)
      if params[key]

        params[key] = params[key].to_s.split(/,\s*/).map do |val|
          Addressable::URI.unescape(val) unless val.nil?
        end
      end
    end

    class NoAdditionalKeysValidator < ActiveModel::Validator
      def validate(record)
        if record.extra_keys.any?
          record.errors[:base] << "Unknown field(s): '#{record.extra_keys.join("', '")}'"
        end
      end
    end

    class StringValuesOnlyValidator < ActiveModel::Validator
      def validate(record)
        if !record.var.is_a?(Hash)
          record.errors[:base] << 'must be a hash'
        else
          record.var.each do |key, value|
            if ![String, NilClass].include?(value.class)
              record.errors[:base] << "Non-string value in environment variable for key '#{key}', value '#{value}'"
            end
          end
        end
      end
    end

    class NoAdditionalParamsValidator < ActiveModel::Validator
      def validate(record)
        if record.extra_keys.any?
          record.errors[:base] << "Unknown query parameter(s): '#{record.extra_keys.join("', '")}'"
        end
      end
    end

    class IncludeParamValidator < ActiveModel::Validator
      def validate(record)
        valid_values = options[:valid_values]

        if record.requested?(:include) && !valid_values.member?(record.include)
          record.errors[:base] << "Invalid included resource: '#{record.include}'"
        end
      end
    end

    private

    def allowed_keys
      self.class::ALLOWED_KEYS
    end
  end
end
