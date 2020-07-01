require 'messages/list_message'

module VCAP::CloudController
  class EventsListMessage < ListMessage
    class CreatedAtValidator < ActiveModel::Validator
      def validate(record)
        if record.requested?(:created_ats)
          if record.created_ats.is_a?(String)
            timestamp = record.created_ats
          else
            unless record.created_ats.is_a?(Hash)
              record.errors[:created_ats] << 'comparison operator and timestamp must be specified'
              return
            end

            comparison_operator = record.created_ats.keys[0]
            valid_comparision_operators = [
              Event::LESS_THAN_COMPARATOR,
              Event::GREATER_THAN_COMPARATOR,
              Event::LESS_THAN_OR_EQUAL_COMPARATOR,
              Event::GREATER_THAN_OR_EQUAL_COMPARATOR,
            ]
            unless valid_comparision_operators.include?(comparison_operator)
              record.errors[:created_ats] << "Invalid comparison operator: '#{comparison_operator}'"
            end

            timestamp = record.created_ats.values[0]
          end
          begin
            raise ArgumentError.new('invalid date') unless timestamp =~ /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\Z/

            Time.iso8601(timestamp)
          rescue
            record.errors[:created_ats] << "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'"
            return
          end
        end
      end
    end

    register_allowed_keys [
      :types,
      :target_guids,
      :space_guids,
      :organization_guids,
      :created_ats
    ]

    validates_with NoAdditionalParamsValidator
    validates_with CreatedAtValidator

    validates :types, array: true, allow_nil: true
    validates :target_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(types target_guids space_guids organization_guids))
    end
  end
end
