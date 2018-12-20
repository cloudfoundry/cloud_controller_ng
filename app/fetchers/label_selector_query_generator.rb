module VCAP::CloudController
  class LabelSelectorQueryGenerator
    class << self
      def add_selector_queries(label_klass:, resource_dataset:, requirements:, resource_klass:, prefilter_labels_by_resource_dataset: false)
        resource_guid_column = Sequel[resource_klass.table_name][:guid]
        label_dataset = label_klass

        if prefilter_labels_by_resource_dataset
          resource_guids = resource_dataset.select(resource_guid_column).map(:guid)
          label_dataset = label_klass.where(resource_guid: resource_guids)
        end

        requirements.reduce(nil) do |accumulated_dataset, requirement|
          case requirement.operator
          when :in
            dataset_for_requirement = evaluate_in(label_dataset, resource_dataset, requirement, resource_klass)
          when :notin
            dataset_for_requirement = evaluate_notin(label_dataset, resource_dataset, requirement, resource_klass)
          when :equal
            dataset_for_requirement = evaluate_equal(label_dataset, resource_dataset, requirement, resource_klass)
          when :not_equal
            dataset_for_requirement = evaluate_not_equal(label_dataset, resource_dataset, requirement, resource_klass)
          when :exists
            dataset_for_requirement = evaluate_exists(label_dataset, resource_dataset, requirement, resource_klass)
          when :not_exists
            dataset_for_requirement = evaluate_not_exists(label_dataset, resource_dataset, requirement, resource_klass)
          end

          if accumulated_dataset.nil?
            dataset_for_requirement
          else
            accumulated_dataset.join(dataset_for_requirement, { guid: resource_guid_column })
          end
        end
      end

      private

      def evaluate_in(label_dataset, resource_dataset, requirement, resource_klass)
        resource_dataset.where(guid: guids_for_set_inclusion(label_dataset, requirement)).qualify(resource_klass.table_name)
      end

      def evaluate_notin(label_dataset, resource_dataset, requirement, resource_klass)
        resource_dataset.exclude(guid: guids_for_set_inclusion(label_dataset, requirement)).qualify(resource_klass.table_name)
      end

      def evaluate_equal(label_dataset, resource_dataset, requirement, resource_klass)
        evaluate_in(label_dataset, resource_dataset, requirement, resource_klass)
      end

      def evaluate_not_equal(label_dataset, resource_dataset, requirement, resource_klass)
        evaluate_notin(label_dataset, resource_dataset, requirement, resource_klass)
      end

      def evaluate_exists(label_dataset, resource_dataset, requirement, resource_klass)
        resource_dataset.where(guid: guids_for_existence(label_dataset, requirement)).qualify(resource_klass.table_name)
      end

      def evaluate_not_exists(label_dataset, resource_dataset, requirement, resource_klass)
        resource_dataset.exclude(guid: guids_for_existence(label_dataset, requirement)).qualify(resource_klass.table_name)
      end

      def guids_for_set_inclusion(label_dataset, requirement)
        label_dataset.
          select(:resource_guid).
          where(key_prefix: requirement.key_prefix, key_name: requirement.key_name, value: requirement.values)
      end

      def guids_for_existence(label_dataset, requirement)
        label_dataset.
          select(:resource_guid).
          where(key_prefix: requirement.key_prefix, key_name: requirement.key_name)
      end
    end
  end
end
