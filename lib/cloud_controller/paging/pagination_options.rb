require 'active_model'
require 'mappers/order_by_mapper'

module VCAP::CloudController
  class PaginationOptions
    include ActiveModel::Model

    PAGE_DEFAULT      = 1
    PER_PAGE_DEFAULT  = 50
    PER_PAGE_MAX      = 5000
    ORDER_DEFAULT     = 'id'.freeze
    DIRECTION_DEFAULT = 'asc'.freeze
    VALID_DIRECTIONS  = %w(asc desc).freeze

    attr_accessor :page, :per_page, :order_by, :order_direction

    validates :page, numericality: { only_integer: true, greater_than: 0 }
    validates :per_page, numericality: {
        only_integer:          true,
        greater_than:          0,
        less_than_or_equal_to: PER_PAGE_MAX,
        message:               "must be between 1 and #{PER_PAGE_MAX}" }
    validates :order_by, inclusion: {
        in:      %w(created_at updated_at id),
        message: "can only be 'created_at' or 'updated_at'"
      }
    validates :order_direction, inclusion: {
        in:      %w(asc desc),
        message: "can only be 'asc' or 'desc'"
      }

    def initialize(params)
      super(params)

      @page ||= PAGE_DEFAULT
      @per_page ||= PER_PAGE_DEFAULT
      @order_by ||= ORDER_DEFAULT
      @order_direction ||= DIRECTION_DEFAULT
    end

    def self.from_params(params)
      page                      = params.delete('page')
      page                      = page.to_i unless page.nil?
      per_page                  = params.delete('per_page')
      per_page                  = per_page.to_i unless per_page.nil?
      raw_order_by              = params.delete('order_by')
      order_by, order_direction = raw_order_by ? OrderByMapper.from_param(raw_order_by) : nil
      options                   = { page: page, per_page: per_page, order_by: order_by, order_direction: order_direction }
      PaginationOptions.new(options)
    end

    def keys
      [:page, :per_page, :order_by, :order_direction]
    end
  end
end
