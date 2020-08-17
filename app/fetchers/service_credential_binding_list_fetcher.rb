module VCAP
  module CloudController
    class ServiceCredentialBindingListFetcher
      def fetch(space_guids:, message: nil)
        dataset = case space_guids
                  when :all
                    ServiceCredentialBinding::View.dataset
                  else
                    ServiceCredentialBinding::View.where { Sequel[:space_guid] =~ space_guids }
                  end

        return dataset if message.nil?

        apply_filters(dataset, message)
      end

      private

      def apply_filters(dataset, message)
        filters_from_message(message).each do |f|
          dataset = dataset.where { f }
        end

        dataset
      end

      FILTERABLE_PROPERTIES = %w{
        service_instance_name
        service_instance_guid
        name
        app_name
        app_guid
        type
      }.freeze

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
