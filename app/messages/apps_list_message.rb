require 'messages/list_message'

module VCAP::CloudController
  class AppsListMessage < ListMessage
    register_allowed_keys [
      :names,
      :guids,
      :organization_guids,
      :space_guids,
      :page,
      :per_page,
      :order_by,
      :order_direction,
      :include,
      :label_selector,
    ]

    def self.label_selector_requested?
      @label_selector_requested ||= proc { |a| a.requested?(:label_selector) }
    end

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space']
    validates_with LabelSelectorRequirementValidator, if: label_selector_requested?

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true

    attr_accessor :requirements

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by])
    end

    def valid_order_by_values
      super << :name
    end

    def self.from_params(params)
      opts = params.dup
      %w(names guids organization_guids space_guids).each do |attribute|
        to_array! opts, attribute
      end

      message = new(opts.symbolize_keys)
      message.requirements = parse_label_selector(message.label_selector)
      message
    end

    def self.parse_label_selector(label_selector)
      return [] unless label_selector

      label_selector.scan(LabelHelpers::REQUIREMENT_SPLITTER).map { |r| parse_requirement(r) }
    end

    def self.parse_requirement(requirement)
      match_data = nil
      requirement_operator_pair = LabelHelpers::REQUIREMENT_OPERATOR_PAIRS.find do |rop|
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
