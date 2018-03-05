require 'messages/nested_message_validator'

module VCAP::CloudController
  class BitsDataValidator < NestedMessageValidator
    validates :data, inclusion: { in: [{}],
                                  message: 'must be empty if provided for bits packages',
                                  allow_nil: true }

    def should_validate?
      record.type == 'bits'
    end

    def error_key
      :data
    end

    delegate :type, :data, to: :record
  end
end
