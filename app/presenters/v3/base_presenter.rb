module VCAP::CloudController
  module Presenters
    module V3
      class BasePresenter
        REDACTED_MESSAGE      = '[PRIVATE DATA HIDDEN]'.freeze
        REDACTED_LIST_MESSAGE = '[PRIVATE DATA HIDDEN IN LISTS]'.freeze

        def initialize(resource, show_secrets: true, censored_message: REDACTED_MESSAGE)
          @resource         = resource
          @show_secrets     = show_secrets
          @censored_message = censored_message
        end

        private

        def redact(unredacted_value)
          @show_secrets ? unredacted_value : @censored_message
        end

        def redact_hash(unredacted_value)
          @show_secrets ? unredacted_value : { 'redacted_message' => @censored_message }
        end
      end
    end
  end
end
