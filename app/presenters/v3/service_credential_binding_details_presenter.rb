require_relative 'base_presenter'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceCredentialBindingDetailsPresenter < BasePresenter
          def to_hash
            {
              credentials: credentials,
              syslog_drain_url: @resource.syslog_drain_url,
              volume_mounts: @resource.volume_mounts || nil
            }.compact
          end

          private

          def credentials
            JSON.parse(@resource.credentials)
          rescue JSON::ParserError
            nil
          end
        end
      end
    end
  end
end
