require 'messages/base_message'

module VCAP::CloudController
  class IsolationSegmentRelationshipOrgMessage < BaseMessage
    ALLOWED_KEYS = [:data].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(body)
      IsolationSegmentRelationshipOrgMessage.new(body.symbolize_keys)
    end

    validates_with NoAdditionalKeysValidator
    validates :data, presence: true, array: true, allow_nil: false, allow_blank: false
    validates_each :data do |record, attr, values|
      if values.is_a? Array
        values.each do |value|
          guid = value['guid']
          record.errors.add attr, "#{guid} not a string" if !guid.is_a? String
        end
      end
    end

    def guids
      data.map { |val| val['guid'] }
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
