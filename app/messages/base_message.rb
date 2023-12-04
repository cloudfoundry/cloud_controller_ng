require 'active_model'
require 'messages/validators'
require 'addressable/uri'

module VCAP::CloudController
  class BaseMessage
    include ActiveModel::Model
    include Validators

    MAX_DB_INT = (2**31) - 1
    MAX_DB_BIGINT = (2**63) - 1

    attr_accessor :requested_keys, :extra_keys

    def self.allowed_keys
      const_defined?(:ALLOWED_KEYS) ? const_get(:ALLOWED_KEYS) : []
    end

    def self.register_allowed_keys(allowed_keys)
      keys = self.allowed_keys + allowed_keys
      const_set(:ALLOWED_KEYS, keys.freeze)
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
        memo[key] = try(key) unless exclude.include?(key)
      end

      request.deep_stringify_keys
    end

    def to_param_hash(exclude: [], fields: [])
      params = {}
      (requested_keys - exclude).each do |key|
        val = try(key)

        if fields.include?(key)
          val.each do |resource, selectors|
            params[:"#{key}[#{resource}]"] = selectors.join(',')
          end
        else
          params[key] = val.is_a?(Array) ? val.map { |v| v.gsub(',', CGI.escape(',')) }.join(',') : val
        end
      end

      params
    end

    def self.from_params(params, to_array_keys, fields: [])
      opts = params.dup
      to_array_keys.each do |attribute|
        to_array! opts, attribute
      end

      fields.each do |key|
        next unless opts[key].is_a?(Hash)

        opts[key].each_key do |attribute|
          to_array! opts[key], attribute
        end
      end

      new(opts.symbolize_keys)
    end

    def self.to_array!(params, key)
      return if params[key].nil?
      return if params[key].is_a?(Hash)

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
        return unless record.extra_keys.any?

        record.errors.add(:base, message: "Unknown field(s): '#{record.extra_keys.join("', '")}'")
      end
    end

    class NoAdditionalParamsValidator < ActiveModel::Validator
      def validate(record)
        return unless record.extra_keys.any?

        record.errors.add(:base, message: "Unknown query parameter(s): '#{record.extra_keys.join("', '")}'. Valid parameters are: '#{record.class.allowed_keys.join("', '")}'")
      end
    end

    class DisallowUpdatedAtsParamValidator < ActiveModel::Validator
      def validate(record)
        return unless record.requested?(:updated_ats)

        record.errors.add(:base, message: "Filtering by 'updated_ats' is not allowed on this resource.")
      end
    end

    class DisallowCreatedAtsParamValidator < ActiveModel::Validator
      def validate(record)
        return unless record.requested?(:created_ats)

        record.errors.add(:base, message: "Filtering by 'created_ats' is not allowed on this resource.")
      end
    end

    class IncludeParamValidator < ActiveModel::Validator
      def validate(record)
        return unless record.requested?(:include)

        key_counts = Hash.new(0)
        record.include.each do |include_candidate|
          if options[:valid_values].member?(include_candidate)
            key_counts[include_candidate] += 1
            record.errors.add(:base, message: "Duplicate included resource: '#{include_candidate}'") if key_counts[include_candidate] == 2
          else
            record.errors.add(:base, message: "Invalid included resource: '#{include_candidate}'. Valid included resources are: '#{options[:valid_values].join("', '")}'")
          end
        end
      end
    end

    class LifecycleTypeParamValidator < ActiveModel::Validator
      def validate(record)
        return unless record.requested?(:lifecycle_type)

        valid_lifecycle_types = [BuildpackLifecycleDataModel::LIFECYCLE_TYPE, DockerLifecycleDataModel::LIFECYCLE_TYPE]
        return if valid_lifecycle_types.include?(record.lifecycle_type)

        record.errors.add(:base, message: "Invalid lifecycle_type: '#{record.lifecycle_type}'")
      end
    end

    private

    def allowed_keys
      self.class::ALLOWED_KEYS
    end
  end
end
