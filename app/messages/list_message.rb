require 'active_model'
require 'messages/validators'
require 'messages/base_message'

module VCAP::CloudController
  class ListMessage < BaseMessage
    include ActiveModel::Model
    include Validators

    ALLOWED_PAGINATION_KEYS = [:page, :per_page, :order_by].freeze

    attr_accessor(*ALLOWED_PAGINATION_KEYS, :pagination_params)
    attr_reader :pagination_options

    def initialize(params={})
      @pagination_params = params.slice(*ALLOWED_PAGINATION_KEYS)
      @pagination_options = PaginationOptions.from_params(params)
      super(params)
    end

    class PaginationOrderValidator < ActiveModel::Validator
      def validate(record)
        order_by = record.pagination_params[:order_by]
        columns_allowed = %w(created_at updated_at).join('|')
        matcher = /^(\+|\-)?(#{columns_allowed})$/
        record.errors.add(:order_by, "can only be 'created_at' or 'updated_at'") unless order_by =~ matcher
      end
    end

    class PaginationPageValidator < ActiveModel::Validator
      def validate(record)
        page = record.pagination_params[:page]
        per_page = record.pagination_params[:per_page]

        validate_page(page, record) if !page.nil?
        validate_per_page(per_page, record) if !per_page.nil?
      end

      def validate_page(value, record)
        record.errors.add(:page, 'must be a positive integer') unless value.to_i > 0
      end

      def validate_per_page(value, record)
        if value.to_i > 0
          record.errors.add(:per_page, 'must be between 1 and 5000') unless value.to_i <= 5000
        else
          record.errors.add(:per_page, 'must be a positive integer')
        end
      end
    end

    validates_with PaginationPageValidator
    validates_with PaginationOrderValidator, if: -> { @pagination_params[:order_by].present? }
  end
end
