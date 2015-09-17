require 'messages/validators'
require 'messages/base_message'

module VCAP::CloudController
  class DropletsListMessage < BaseMessage
    ALLOWED_KEYS = [:app_guids, :states, :page, :per_page, :order_by]
    VALID_ORDER_BY_KEYS = /created_at|updated_at/

    attr_accessor(*ALLOWED_KEYS)

    validates :app_guids, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true
    validates_numericality_of :page, greater_than: 0, allow_nil: true
    validates_numericality_of :per_page, greater_than: 0, allow_nil: true
    validates_format_of :order_by, with: /[+-]?(#{VALID_ORDER_BY_KEYS})/, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def error_message
      'Unknown parameter(s):'
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
