module VCAP::CloudController
  class LabelSelectorQueryGenerator
    class << self
      def add_selector_queries(label_klass:, resource_dataset:, requirements:, resource_klass:)
        resource_guid = Sequel.qualify(resource_klass.table_name, :guid)
        requirements.each do |requirement|
          case requirement.operator
          when :in, :equal
            resource_dataset = resource_dataset.where(resource_guid => guids_for_set_inclusion(label_klass, requirement))
          when :notin, :not_equal
            resource_dataset = resource_dataset.exclude(resource_guid => guids_for_set_inclusion(label_klass, requirement))
          when :exists
            resource_dataset = resource_dataset.where(resource_guid => guids_for_existence(label_klass, requirement))
          when :not_exists
            resource_dataset = resource_dataset.exclude(resource_guid => guids_for_existence(label_klass, requirement))
          end
        end
        resource_dataset.qualify(resource_klass.table_name)
      end

      private

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
