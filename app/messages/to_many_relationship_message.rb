require 'messages/base_message'

module VCAP::CloudController
  class ToManyRelationshipMessage < BaseMessage
    class DataParamGUIDValidator < ActiveModel::Validator
      def validate(record)
        return unless record.requested?(:data)

        values = record.data
        return unless values.is_a? Array

        values.each_with_index do |value, index|
          guid = value[:guid]
          record.errors.add(:base, "Invalid data type: Data[#{index}] guid should be a string.") unless guid.is_a? String
        end
      end
    end

    register_allowed_keys [:data]

    validates_with NoAdditionalKeysValidator
    validates :data, presence: true, array: true, allow_nil: false, allow_blank: false
    validates_with DataParamGUIDValidator

    def guids
      data.pluck(:guid)
    end
  end
end
