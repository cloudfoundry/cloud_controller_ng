module VCAP::CloudController
  class LabelSelectorParser
    class << self
      def add_selector_queries(label_klass:, resource_dataset:, label_selector:)
        parse_requirements(label_selector).reduce(nil) do |accumulated_dataset, requirement|
          case requirement.operator
          when :in
            dataset_for_requirement = evaluate_in(label_klass, resource_dataset, requirement)
          when :notin
            dataset_for_requirement = evaluate_notin(label_klass, resource_dataset, requirement)
          when :equal
            dataset_for_requirement = evaluate_equal(label_klass, resource_dataset, requirement)
          when :not_equal
            dataset_for_requirement = evaluate_not_equal(label_klass, resource_dataset, requirement)
          when :exists
            dataset_for_requirement = evaluate_exists(label_klass, resource_dataset, requirement)
          when :not_exists
            dataset_for_requirement = evaluate_not_exists(label_klass, resource_dataset, requirement)
          end

          accumulated_dataset.nil? ? dataset_for_requirement : accumulated_dataset.join(dataset_for_requirement, [:guid])
        end
      end

      private

      def parse_requirements(label_selector)
        requirements = []

        split_selector(label_selector).each do |requirement|
          VCAP::CloudController::LabelHelpers::REQUIREMENT_OPERATOR_PAIRS.each do |requirement_operator_pair|
            operator_pattern = requirement_operator_pair[:pattern]
            operator_type = requirement_operator_pair[:operator]

            match_data = operator_pattern.match(requirement)
            next if match_data.nil?

            requirements << LabelSelectorRequirement.new(key: match_data[:key], operator: operator_type, values: match_data[:values])
            break
          end
        end

        requirements
      end

      def split_selector(label_selector)
        label_selector.scan(VCAP::CloudController::LabelHelpers::REQUIREMENT_SPLITTER)
      end

      def evaluate_in(label_klass, resource_dataset, requirement)
        resource_dataset.where(guid: guids_for_set_inclusion(label_klass, requirement))
      end

      def evaluate_notin(label_klass, resource_dataset, requirement)
        resource_dataset.exclude(guid: guids_for_set_inclusion(label_klass, requirement))
      end

      def evaluate_equal(label_klass, resource_dataset, requirement)
        evaluate_in(label_klass, resource_dataset, requirement)
      end

      def evaluate_not_equal(label_klass, resource_dataset, requirement)
        evaluate_notin(label_klass, resource_dataset, requirement)
      end

      def evaluate_exists(label_klass, resource_dataset, requirement)
        resource_dataset.where(guid: guids_for_existence(label_klass, requirement))
      end

      def evaluate_not_exists(label_klass, resource_dataset, requirement)
        resource_dataset.exclude(guid: guids_for_existence(label_klass, requirement))
      end

      def guids_for_set_inclusion(label_klass, requirement)
        label_klass.
          select(label_klass::RESOURCE_GUID_COLUMN).
          where(key_prefix: requirement.key_prefix, key_name: requirement.key_name, value: requirement.values)
      end

      def guids_for_existence(label_klass, requirement)
        label_klass.
          select(label_klass::RESOURCE_GUID_COLUMN).
          where(key_prefix: requirement.key_prefix, key_name: requirement.key_name)
      end
    end
  end

  class LabelSelectorRequirement
    attr_accessor :key_name, :key_prefix, :operator, :values

    def initialize(key:, operator:, values:)
      @key_prefix, @key_name = VCAP::CloudController::LabelHelpers.extract_prefix(key)
      @operator = operator
      @values = values.split(',')
    end
  end
end
