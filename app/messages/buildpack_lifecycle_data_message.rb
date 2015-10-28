module VCAP::CloudController
  class BuildpackLifecycleDataMessage < BaseMessage
    ALLOWED_KEYS = [:buildpack, :stack].freeze

    attr_accessor(*ALLOWED_KEYS)
    def allowed_keys
      ALLOWED_KEYS
    end
    validates_with NoAdditionalKeysValidator

    def self.stack_requested?
      proc { |message| message.requested?(:stack) }
    end

    validates :stack,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if: stack_requested?

    validates :buildpack,
      string: true,
      allow_nil: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' }

    validate :stack_name_must_be_in_db

    def stack_name_must_be_in_db
      return unless stack.is_a?(String)
      if Stack.find(name: stack).nil?
        errors.add(:stack, 'is invalid')
      end
    end
  end
end
