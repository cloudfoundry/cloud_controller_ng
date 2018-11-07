module VCAP::CloudController
  class LabelSelectorQueryGenerator
    class << self
      def add_selector_queries(label_klass:, resource_dataset:, requirements:)
        requirements.reduce(nil) do |accumulated_dataset, requirement|
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
          select(:resource_guid).
          where(key_prefix: requirement.key_prefix, key_name: requirement.key_name, value: requirement.values)
      end

      def guids_for_existence(label_klass, requirement)
        label_klass.
          select(:resource_guid).
          where(key_prefix: requirement.key_prefix, key_name: requirement.key_name)
      end
    end
  end
end
