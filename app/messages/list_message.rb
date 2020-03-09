require 'active_model'
require 'messages/validators'
require 'messages/base_message'

module VCAP::CloudController
  class ListMessage < BaseMessage
    include ActiveModel::Model
    include Validators

    ALLOWED_PAGINATION_KEYS = [:page, :per_page, :order_by].freeze

    register_allowed_keys ALLOWED_PAGINATION_KEYS

    # Disallow directly calling <any>ListMessage.new
    # All ListMessage classes should be instantiated via the from_params method
    private_class_method :new

    attr_accessor(*ALLOWED_PAGINATION_KEYS, :pagination_params)
    attr_reader :pagination_options

    def initialize(params={}, comparable_params=nil)
      comparable_params ||= { gt_params: [], lt_params: [] }
      params = params.symbolize_keys
      @pagination_params = params.slice(*ALLOWED_PAGINATION_KEYS)
      @pagination_options = PaginationOptions.from_params(params)
      @comparable_params = comparable_params
      super(params)
    end

    def gt_params
      @comparable_params[:gt_params]
    end

    def lt_params
      @comparable_params[:lt_params]
    end

    def to_param_hash(exclude: [])
      super(exclude: ALLOWED_PAGINATION_KEYS + exclude)
    end

    class PaginationOrderValidator < ActiveModel::Validator
      def validate(record)
        order_by = record.pagination_params[:order_by]
        columns_allowed = record.valid_order_by_values.join('|')
        matcher = /\A(\+|\-)?(#{columns_allowed})\z/

        unless order_by.match?(matcher)
          valid_values_message = record.valid_order_by_values.map { |value| "'#{value}'" }.join(', ')
          record.errors.add(:order_by, "can only be: #{valid_values_message}")
        end
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

    # override this to define valid fields to order by
    def valid_order_by_values
      [:created_at, :updated_at]
    end

    validates_with PaginationPageValidator
    validates_with PaginationOrderValidator, if: -> { @pagination_params[:order_by].present? }

    def self.from_params(params, to_array_keys, comparable_keys=[])
      opts = params.dup

      comparable_params = {
        gt_params: [],
        lt_params: [],
      }

      comparable_keys.each do |param|
        make_it_good! opts, param, comparable_params
      end

      to_array_keys.each do |attribute|
        to_array! opts, attribute
      end

      message = new(opts.symbolize_keys, comparable_params)
      message.requirements = parse_label_selector(opts.symbolize_keys[:label_selector]) if message.requested?(:label_selector)

      message
    end

    GREATER_THAN = 'gt'.freeze
    LESS_THAN = 'lt'.freeze

    def self.make_it_good!(params, key, comparable_params)
      param_in_question = params[key]
      return if param_in_question.nil?

      if param_in_question.respond_to?(:key?)
        if param_in_question.key?(GREATER_THAN)
          params[key] = param_in_question[GREATER_THAN]
          comparable_params[:gt_params] << key
        elsif param_in_question.key?(LESS_THAN)
          params[key] = param_in_question[LESS_THAN]
          comparable_params[:lt_params] << key
        end
      end
    end

    attr_accessor :requirements

    def self.parse_label_selector(label_selector)
      return [] unless label_selector

      label_selector.scan(MetadataHelpers::REQUIREMENT_SPLITTER).map { |r| parse_requirement(r) }
    end

    def self.parse_requirement(requirement)
      match_data = nil
      requirement_operator_pair = MetadataHelpers::REQUIREMENT_OPERATOR_PAIRS.find do |rop|
        match_data = rop[:pattern].match(requirement)
      end
      return nil unless requirement_operator_pair

      LabelSelectorRequirement.new(
        key: match_data[:key],
        operator: requirement_operator_pair[:operator],
        values: match_data[:values],
      )
    end
  end
end
