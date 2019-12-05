module VCAP::CloudController
  class LabelSelectorQueryGenerator
    class << self
      def add_selector_queries(label_klass:, resource_dataset:, requirements:, resource_klass:)
        requirements.reduce(nil) do |accumulated_dataset, requirement|
          case requirement.operator
          when :in
            dataset_for_requirement = evaluate_in(label_klass, resource_dataset, requirement, resource_klass)
          when :notin
            dataset_for_requirement = evaluate_notin(label_klass, resource_dataset, requirement, resource_klass)
          when :equal
            dataset_for_requirement = evaluate_equal(label_klass, resource_dataset, requirement, resource_klass)
          when :not_equal
            dataset_for_requirement = evaluate_not_equal(label_klass, resource_dataset, requirement, resource_klass)
          when :exists
            dataset_for_requirement = evaluate_exists(label_klass, resource_dataset, requirement, resource_klass)
          when :not_exists
            dataset_for_requirement = evaluate_not_exists(label_klass, resource_dataset, requirement, resource_klass)
          end
          # Doing multiple self-joins here instead of building a chain of WHERE/AND
          # clauses for performance concerns. It may be worthwhile in the future to do a performance
          # benchmark or comparision of the two execution plans to see if that is a large concern
          if accumulated_dataset.nil?
            dataset_for_requirement
          else
            accumulated_dataset.join(dataset_for_requirement, { guid: Sequel[resource_klass.table_name][:guid] })
          end
        end
      end

      private

      def evaluate_in(label_klass, resource_dataset, requirement, resource_klass)
        resource_dataset.
          where(Sequel.qualify(resource_klass.table_name, :guid) => guids_for_set_inclusion(label_klass, requirement)).
          qualify(resource_klass.table_name)
      end

      def evaluate_notin(label_klass, resource_dataset, requirement, resource_klass)
        resource_dataset.
          exclude(Sequel.qualify(resource_klass.table_name, :guid) => guids_for_set_inclusion(label_klass, requirement)).
          qualify(resource_klass.table_name)
      end

      def evaluate_equal(label_klass, resource_dataset, requirement, resource_klass)
        evaluate_in(label_klass, resource_dataset, requirement, resource_klass)
      end

      def evaluate_not_equal(label_klass, resource_dataset, requirement, resource_klass)
        evaluate_notin(label_klass, resource_dataset, requirement, resource_klass)
      end

      def evaluate_exists(label_klass, resource_dataset, requirement, resource_klass)
        resource_dataset.
          where(Sequel.qualify(resource_klass.table_name, :guid) => guids_for_existence(label_klass, requirement)).
          qualify(resource_klass.table_name)
      end

      def evaluate_not_exists(label_klass, resource_dataset, requirement, resource_klass)
        resource_dataset.
          exclude(Sequel.qualify(resource_klass.table_name, :guid) => guids_for_existence(label_klass, requirement)).
          qualify(resource_klass.table_name)
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
