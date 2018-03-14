require 'messages/base_message'

module VCAP::CloudController
  class ManifestProcessScaleMessage < BaseMessage
    ALLOWED_KEYS = [:instances, :memory, :disk_quota].freeze
    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    invalid_field_message = ->(object, data) do
      if object.nil?
        return invalid_field_message_with_nil_object(data)
      end
      case object.to_s.split('.')[-1]
      when 'not_a_number'
        return 'is not a number'
      when 'greater_than'
        return 'must be greater than 0MB'
      when 'not_an_integer'
        return 'must be an integer'
      else
        Steno.logger('ManifestProcessScaleMessage#invalid_field_message').warn("Unexpected error code of data:<#{data || 'nil'}>, object:<#{object}>")
        return 'is not a number'
      end
    end

    validates :instances, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :memory, numericality: { only_integer: true, greater_than: 0, message: invalid_field_message }, allow_nil: true
    validates :disk_quota, numericality: { only_integer: true, greater_than: 0, message: invalid_field_message }, allow_nil: true

    def self.create_from_http_request(body)
      ManifestProcessScaleMessage.new(body.deep_symbolize_keys)
    end

    # Sometimes ActiveModel can't resolve the error key against the class,
    # so we have to examine the value alone.
    # The object field is based on @base.class.lookup_ancestors[0].model_name.i18n_key,
    # but if @base.class doesn't have a `i18n_scope` method, `object` is nil, so we
    # have to analyze the data.
    def self.invalid_field_message_with_nil_object(data)
      value_as_string = data[:value].to_s
      begin
        Float(value_as_string)
      rescue ArgumentError
        return 'is not a number'
      end
      begin
        value = Integer(value_as_string)
      rescue ArgumentError
        return 'must be an integer'
      end
      if value <= 0
        return 'must be greater than 0MB'
      end
      Steno.logger('ManifestProcessScaleMessage#invalid_field_message').warn("Unexpected error with nil object, data:<#{data}>")
      'is not a number'
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
