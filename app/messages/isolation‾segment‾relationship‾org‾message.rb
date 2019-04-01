require 'messages/base_message'

module VCAP::CloudController
  class IsolationSegmentRelationshipOrgMessage < BaseMessage
    register_allowed_keys [:data]

    validates_with NoAdditionalKeysValidator
    validates :data, presence: true, array: true, allow_nil: false, allow_blank: false
    validates_each :data do |record, attr, values|
      if values.is_a? Array
        values.each do |value|
          guid = value[:guid]
          record.errors.add attr, "#{guid} not a string" if !guid.is_a? String
        end
      end
    end

    def guids
      data.map { |val| val[:guid] }
    end
  end
end
