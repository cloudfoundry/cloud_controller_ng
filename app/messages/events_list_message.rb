require 'messages/list_message'

module VCAP::CloudController
  class EventsListMessage < ListMessage
    class CreatedAtValidator < ActiveModel::Validator
      def validate(record)
        if record.requested?(:created_at)
          unless record.created_at.is_a?(Hash)
            record.errors[:created_at] << 'comparison operator and timestamp must be specified'
            return
          end

          comparison_operator = record.created_at.keys[0]
          valid_comparision_operators = [Event::LESS_THAN_COMPARATOR]
          unless valid_comparision_operators.include?(comparison_operator)
            record.errors[:created_at] << "Invalid comparison operator: '#{comparison_operator}'"
          end

          timestamp = record.created_at.values[0]
          begin
            Time.iso8601(timestamp)
          rescue
            record.errors[:created_at] << "Invalid timestamp format: '#{timestamp}'"
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
      :created_at
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
