require 'messages/nested_message_validator'

module VCAP::CloudController
  class DockerDataValidator < NestedMessageValidator
    validates :image, string: true, presence: { message: 'required' }

    delegate :type, :data, to: :record

    def image
      record.try(:data).try(:fetch, :image, nil)
    end

    def should_validate?
      record.type == 'docker'
    end

    def error_key
      :data
    end
  end
end
