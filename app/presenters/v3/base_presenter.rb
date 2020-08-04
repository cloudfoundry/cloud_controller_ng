require 'presenters/helpers/censorship'
require 'presenters/api_url_builder'

module VCAP
  module CloudController
    module Presenters
      module V3
        class BasePresenter
          def initialize(resource, show_secrets: true, censored_message: Censorship::PRIVATE_DATA_HIDDEN, decorators: [])
            @resource = resource
            @show_secrets = show_secrets
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

          def url_builder
            @url_builder ||= VCAP::CloudController::Presenters::ApiUrlBuilder
          end
        end
      end
    end
  end
end
