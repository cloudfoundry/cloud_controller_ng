require 'messages/validators'
require 'messages/base_message'

module VCAP::CloudController
  class AppsListMessage < BaseMessage
    ALLOWED_KEYS = [:names, :guids, :organization_guids, :space_guids, :page, :per_page, :order_by]
    VALID_ORDER_BY_KEYS = /created_at|updated_at/

    attr_accessor(*ALLOWED_KEYS)

    validates :names, array: true, allow_blank: true
    validates :guids, array: true, allow_blank: true
    validates :organization_guids, array: true, allow_blank: true
    validates :space_guids, array: true, allow_blank: true
    validates_numericality_of :page, greater_than: 0, allow_blank: true
    validates_numericality_of :per_page, greater_than: 0, allow_blank: true
    validates_format_of :order_by, with: /[+-]?(#{VALID_ORDER_BY_KEYS})/, allow_blank: true

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
