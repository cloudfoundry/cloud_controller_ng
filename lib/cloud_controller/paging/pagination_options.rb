require 'active_model'

module VCAP::CloudController
  class PaginationOptions
    include ActiveModel::Model

    PAGE_DEFAULT      = 1
    PER_PAGE_DEFAULT  = 50
    PER_PAGE_MAX      = 5000
    ORDER_DEFAULT     = 'id'
    DIRECTION_DEFAULT = 'asc'
    VALID_DIRECTIONS  = %w(asc desc)

    attr_accessor :page, :per_page, :order_by, :order_direction

    validates :page, numericality: { only_integer: true, greater_than: 0 }
    validates :per_page, numericality: {
        only_integer:          true,
        greater_than:          0,
        less_than_or_equal_to: PER_PAGE_MAX,
        message:               "must be between 1 and #{PER_PAGE_MAX}" }
    validates :order_by, inclusion: {
        in:      %w(created_at updated_at id),
        message: "can only be ordered by 'created_at' or 'updated_at'"
      }
    validates :order_direction, inclusion: {
        in:      %w(asc desc),
        message: "can only be 'asc' or 'desc'"
      }

    def initialize(params)
      super(params)

      @page            ||= PAGE_DEFAULT
      @per_page        ||= PER_PAGE_DEFAULT
      @order_by        ||= ORDER_DEFAULT
      @order_direction ||= DIRECTION_DEFAULT
    end

    class << self
      def from_params(params)
        page                      = params.delete('page')
        page                      = page.to_i unless page.nil?
        per_page                  = params.delete('per_page')
        per_page                  = per_page.to_i unless per_page.nil?
        order_by, order_direction = parse_order(params.delete('order_by'))
        options                   = { page: page, per_page: per_page, order_by: order_by, order_direction: order_direction }
        PaginationOptions.new(options)
      end

      private

      def parse_order(raw_order_by)
        return unless raw_order_by

        first_character = raw_order_by[0]

        if user_provided_direction?(first_character)
          order_by = remove_prefix(raw_order_by)
          order_direction = parse_order_direction(first_character)
        else
          order_by = raw_order_by
          order_direction = nil
        end

        return order_by, order_direction
      end

      ORDER_PREFIXES = %w(+ -)
      def user_provided_direction?(first_character)
        ORDER_PREFIXES.include? first_character
      end

      def parse_order_direction(first_character)
        first_character == '+' ? 'asc' : 'desc'
      end

      def remove_prefix(order_by)
        order_by[1..-1]
      end
    end

    def keys
      [:page, :per_page, :order_by, :order_direction]
    end
  end
end
