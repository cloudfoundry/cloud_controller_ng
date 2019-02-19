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

    attr_writer :order_by, :order_direction, :default_order_by
    attr_accessor :page, :per_page

    def initialize(params)
      super(params)

      @page ||= PAGE_DEFAULT
      @per_page ||= PER_PAGE_DEFAULT
    end

    def self.from_params(params)
      page                      = params[:page].to_i if params[:page].present?
      per_page                  = params[:per_page].to_i if params[:per_page].present?
      order_by, order_direction = params[:order_by].present? ? OrderByMapper.from_param(params[:order_by]) : nil
      options                   = { page: page, per_page: per_page, order_by: order_by, order_direction: order_direction }
      PaginationOptions.new(options)
    end

    def order_by
      @order_by || default_order_by
    end

    def order_direction
      @order_direction || DIRECTION_DEFAULT
    end

    def keys
      [:page, :per_page, :order_by, :order_direction]
    end

    def ordering_configured?
      @order_by.present? || @order_direction.present?
    end

    private

    def default_order_by
      @default_order_by || ORDER_DEFAULT
    end
  end
end
