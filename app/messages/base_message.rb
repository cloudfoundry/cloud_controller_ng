require 'active_model'
require 'messages/validators'

module VCAP::CloudController
  class BaseMessage
    include ActiveModel::Model
    include Validators

    attr_accessor :requested_keys, :extra_keys

    def self.register_allowed_keys(allowed_keys)
      current_keys = const_defined?(:ALLOWED_KEYS) ? self.const_get(:ALLOWED_KEYS) : []

      keys = current_keys + allowed_keys
      self.const_set(:ALLOWED_KEYS, keys.freeze)
      attr_accessor(*allowed_keys)
    end

    def initialize(params)
      params = params ? params.deep_symbolize_keys : {}
      @requested_keys = params.keys
      disallowed_params = params.slice!(*allowed_keys)
      @extra_keys = disallowed_params.keys
      super(params)
    end

    def requested?(key)
      requested_keys.include?(key)
    end

    def audit_hash(exclude: [])
      request = {}

      requested_keys.each_with_object(request) do |key, memo|
        memo[key] = self.try(key) unless exclude.include?(key)
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

    def self.from_params(params, to_array_keys)
      opts = params.dup
      to_array_keys.each do |attribute|
        to_array! opts, attribute
      end
      message = new(opts.symbolize_keys)
      message
    end

    def self.to_array!(params, key)
      return if params[key].nil?

      params[key] = if params[key] == ''
                      ['']
                    else
                      params[key].to_s.split(/,\s*/, -1).map do |val|
                        Addressable::URI.unescape(val)
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
        if record.requested?(:include)
          key_counts = Hash.new(0)
          record.include.each do |include_candidate|
            if !options[:valid_values].member?(include_candidate)
              record.errors[:base] << "Invalid included resource: '#{include_candidate}'"
            else
              key_counts[include_candidate] += 1
              if key_counts[include_candidate] == 2
                record.errors[:base] << "Duplicate included resource: '#{include_candidate}'"
              end
            end
          end
        end
      end
    end

    private

    def allowed_keys
      self.class::ALLOWED_KEYS
    end
  end
end
