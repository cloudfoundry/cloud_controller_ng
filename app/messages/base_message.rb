require 'active_model'
require 'messages/validators'

module VCAP::CloudController
  class BaseMessage
    include ActiveModel::Model
    include Validators

    attr_accessor :requested_keys, :extra_keys

    def initialize(params={})
      params ||= {}
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
      requested_keys.each do |key|
        next if exclude.include?(key)
        request[key.to_s] = self.try(key)
      end
      request
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
        params[key] = params[key].to_s.split(',').map { |val| CGI.unescape(val) unless val.nil? }
      end
    end

    class NoAdditionalKeysValidator < ActiveModel::Validator
      def validate(record)
        if record.extra_keys.any?
          record.errors[:base] << "Unknown field(s): '#{record.extra_keys.join("', '")}'"
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

    private

    def allowed_keys
      raise NotImplementedError
    end
  end
end
