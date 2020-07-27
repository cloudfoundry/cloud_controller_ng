require 'messages/list_message'

module VCAP::CloudController
  class EventsListMessage < ListMessage
    class CreatedAtValidator < ActiveModel::Validator
      def validate(record)
        filters = {}
        filters[:created_ats] = record.created_ats if record.requested?(:created_ats)
        filters[:updated_ats] = record.updated_ats if record.requested?(:updated_ats)

        filters.each do |filter, values|
          if record.requested?(filter)
            if values.is_a?(Array)
              values.each do |timestamp|
                opinionated_iso_8601(timestamp, record, filter)
              end
            else
              unless values.is_a?(Hash)
                record.errors[filter] << 'relational operator and timestamp must be specified'
                next
              end

              valid_relational_operators = [
                Event::LESS_THAN_COMPARATOR,
                Event::GREATER_THAN_COMPARATOR,
                Event::LESS_THAN_OR_EQUAL_COMPARATOR,
                Event::GREATER_THAN_OR_EQUAL_COMPARATOR,
              ]

              values.each do |relational_operator, timestamp|
                unless valid_relational_operators.include?(relational_operator)
                  record.errors[filter] << "Invalid relational operator: '#{relational_operator}'"
                end

                if timestamp.to_s.include?(',')
                  record.errors[filter] << 'only accepts one value when using a relational operator'
                  next
                end

                opinionated_iso_8601(timestamp, record, filter)
              end
            end
          end
        end
      end

      private

      def opinionated_iso_8601(timestamp, record, filter)
        if timestamp !~ /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\Z/
          record.errors[filter] << "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'"
        end
      end
    end

    register_allowed_keys [
      :types,
      :target_guids,
      :space_guids,
      :organization_guids,
      :created_ats,
      :updated_ats
    ]

    validates_with NoAdditionalParamsValidator
    validates_with CreatedAtValidator

    validates :types, array: true, allow_nil: true
    validates :target_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(types target_guids space_guids organization_guids created_ats updated_ats))
    end
  end
end
