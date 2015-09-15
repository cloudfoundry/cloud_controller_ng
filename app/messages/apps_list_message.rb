require 'messages/validators'

module VCAP::CloudController
  class AppsListMessage
    include ActiveModel::Model
    include VCAP::CloudController::Validators

    VALID_ORDER_BY_KEYS = %r(created_at|updated_at)

    attr_accessor :names, :guids, :organization_guids, :space_guids, :page, :per_page, :order_by

    validates :names, array: true, allow_blank: true
    validates :guids, array: true, allow_blank: true
    validates :organization_guids, array: true, allow_blank: true
    validates :space_guids, array: true, allow_blank: true
    validates_numericality_of :page, greater_than: 0, allow_blank: true
    validates_numericality_of :per_page, greater_than: 0, allow_blank: true
    validates_format_of :order_by, with: /[+-]?(#{VALID_ORDER_BY_KEYS})/, allow_blank: true
  end
end
