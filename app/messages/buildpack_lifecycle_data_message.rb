module VCAP::CloudController
  class BuildpackLifecycleDataMessage < BaseMessage
    ALLOWED_KEYS = [:buildpack, :stack].freeze

    attr_accessor(*ALLOWED_KEYS)
    def allowed_keys
      ALLOWED_KEYS
    end
    validates_with NoAdditionalKeysValidator

    validates :stack,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      allow_nil: true

    validates :buildpack,
      string: true,
      allow_nil: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' }

    validate :stack_name_must_be_in_db

    def stack_name_must_be_in_db
      return unless stack.is_a?(String)
      if Stack.find(name: stack).nil?
        errors.add(:stack, 'must exist in our DB')
      end
    end
  end
end
