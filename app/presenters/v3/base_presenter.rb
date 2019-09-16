require 'presenters/helpers/censorship'

module VCAP::CloudController
  module Presenters
    module V3
      class BasePresenter
        def initialize(resource, show_secrets: true, censored_message: Censorship::PRIVATE_DATA_HIDDEN, decorators: [])
          @resource         = resource
          @show_secrets     = show_secrets
          @censored_message = censored_message
          @decorators = decorators
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
