module CloudController
  module Redactor
    REDACTED_MESSAGE = '[PRIVATE DATA HIDDEN]'.freeze
    REDACTED_HASH    = { 'redacted_message'.freeze => REDACTED_MESSAGE }.freeze

    private

    def redact(unredacted_value, show_unredacted_value)
      show_unredacted_value ? unredacted_value : REDACTED_MESSAGE
    end

    def redact_hash(unredacted_value, show_unredacted_value)
      show_unredacted_value ? unredacted_value : REDACTED_HASH
    end
  end
end
