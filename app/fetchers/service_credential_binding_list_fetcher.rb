require 'fetchers/base_list_fetcher'
require 'fetchers/label_selector_query_generator'

module VCAP
  module CloudController
    class ServiceCredentialBindingListFetcher < BaseListFetcher
      class << self
        FILTERABLE_PROPERTIES = %w{
          service_instance_name
          service_instance_guid
          name
          app_name
          app_guid
          type
          service_plan_name
          service_plan_guid
          service_offering_name
          service_offering_guid
        }.freeze

        def fetch(readable_spaces_query: nil, message: nil, eager_loaded_associations: [])
          dataset = case readable_spaces_query
                    when nil
                      ServiceCredentialBinding::View.dataset
                    else
                      ServiceCredentialBinding::View.where { Sequel[:space_id] =~ readable_spaces_query.select(:id) }
                    end

          dataset = dataset.eager(eager_loaded_associations)

          return dataset if message.nil?

          filter(dataset, message)
        end

        private

        def filter(dataset, message)
          filters_from_message(message).each do |f|
            dataset = dataset.where { f }
          end

          if message.requested?(:label_selector)
            dataset = LabelSelectorQueryGenerator.add_selector_queries(
              label_klass: ServiceCredentialBindingLabels::View,
              resource_dataset: dataset,
              requirements: message.requirements,
              resource_klass: ServiceCredentialBinding::View
            )
          end

          super(message, dataset, ServiceCredentialBinding::View)
        end

        def filters_from_message(message)
          FILTERABLE_PROPERTIES.
            select { |property| message.requested?(message_param_for(property)) }.
            reduce([]) { |clauses, property| clauses << build_where_clause(message, property) }
        end

        def build_where_clause(message, field)
          message_param = message_param_for(field)
          Sequel[field.to_sym] =~ message.public_send(message_param)
        end

        def message_param_for(field)
          case field
          when 'type'
            :type
          else
            field.pluralize.to_sym
          end
        end
      end
    end
  end
end
