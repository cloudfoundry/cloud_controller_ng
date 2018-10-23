module VCAP::CloudController
  class LabelSelectorParser
    class << self
      def add_selector_queries(label_klass, resource_dataset, label_selector)
        parse_requirements(label_selector).reduce(nil) do |dataset, req|
          case req.operator
          when :in
            ds = evaluate_in(label_klass, resource_dataset, req)
          when :notin
            ds = evaluate_notin(label_klass, resource_dataset, req)
          end

          if dataset.nil?
            ds
          else
            dataset.natural_join(ds)
          end
        end
      end

      private

      def parse_requirements(label_selector)
        requirements = []

        split_selector(label_selector).each do |requirement|
          VCAP::CloudController::LabelHelpers::REQUIREMENT_OPERATOR_PAIRS.each do |rop|
            match = rop[:pattern].match(requirement)
            next if match.nil?

            requirements << LabelSelectorRequirement.new(key: match[:key], operator: rop[:operator], values: match[:values])
          end
        end

        requirements
      end

      def split_selector(label_selector)
        label_selector.scan(VCAP::CloudController::LabelHelpers::REQUIREMENT_SPLITTER)
      end

      def evaluate_in(label_klass, resource_dataset, requirement)
        resource_dataset.where(guid: set_inclusion_guids(label_klass, requirement))
      end

      def evaluate_notin(label_klass, resource_dataset, requirement)
        resource_dataset.exclude(guid: set_inclusion_guids(label_klass, requirement))
      end

      def set_inclusion_guids(label_klass, requirement)
        prefix, name = VCAP::CloudController::LabelHelpers.extract_prefix(requirement.key)
        label_klass.
          select(label_klass::RESOURCE_GUID_COLUMN).
          where(key_prefix: prefix, key_name: name, value: requirement.values)
      end
    end
  end

  class LabelSelectorRequirement
    attr_accessor :key, :operator, :values

    def initialize(key:, operator:, values:)
      @key = key
      @operator = operator
      @values = values.split(',')
    end
  end
end
