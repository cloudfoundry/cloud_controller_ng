require 'messages/validators'

module VCAP::CloudController
  class AppsDropletsListMessage
    include ActiveModel::Model
    include VCAP::CloudController::Validators

    VALID_ORDER_BY_KEYS = %w(created_at updated_at)
    VALID_ORDER_DIRECTIONS = %w(asc desc)

    attr_accessor :states, :page, :per_page, :order_by, :order_direction

    validates :states, array: true, allow_blank: true
    validates_numericality_of :page, greater_than: 0, allow_blank: true
    validates_numericality_of :per_page, greater_than: 0, allow_blank: true
    validates_inclusion_of :order_by, in: VALID_ORDER_BY_KEYS, allow_blank: true
    validates_inclusion_of :order_direction, in: VALID_ORDER_DIRECTIONS, allow_blank: true
  end
end
