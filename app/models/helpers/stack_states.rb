module VCAP::CloudController
  class StackStates
    STACK_ACTIVE = 'ACTIVE'.freeze
    STACK_RESTRICTED = 'RESTRICTED'.freeze
    STACK_DEPRECATED = 'DEPRECATED'.freeze
    STACK_DISABLED = 'DISABLED'.freeze

    DEFAULT_STATE = STACK_ACTIVE

    VALID_STATES = [
      STACK_ACTIVE,
      STACK_RESTRICTED,
      STACK_DEPRECATED,
      STACK_DISABLED
    ].freeze
  end
end
