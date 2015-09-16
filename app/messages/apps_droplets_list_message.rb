require 'messages/validators'

module VCAP::CloudController
  class AppsDropletsListMessage
    include ActiveModel::Model
    include VCAP::CloudController::Validators

    VALID_ORDER_BY_KEYS = /created_at|updated_at/

    attr_accessor :states, :page, :per_page, :order_by

    validates :states, array: true, allow_blank: true
    validates_numericality_of :page, greater_than: 0, allow_blank: true
    validates_numericality_of :per_page, greater_than: 0, allow_blank: true
    validates_format_of :order_by, with: /[+-]?(#{VALID_ORDER_BY_KEYS})/, allow_blank: true
  end
end
