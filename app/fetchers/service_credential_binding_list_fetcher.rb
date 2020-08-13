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

      def filters_from_message(message)
        %w{service_instance_name service_instance_guid name}.map do |field|
          filter = field.pluralize.to_sym
          if message.requested?(filter)
            (Sequel[field.to_sym] =~ message.public_send(filter))
          end
        end.compact
      end
    end
  end
end
