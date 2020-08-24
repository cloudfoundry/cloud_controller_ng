require_relative 'base_presenter'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceCredentialBindingDetailsPresenter < BasePresenter
          def initialize(binding:, credentials:)
            super(binding)
            @credentials = credentials
          end

          def to_hash
            {
              credentials: @credentials,
              syslog_drain_url: @resource.try(:syslog_drain_url) || nil,
              volume_mounts: @resource.try(:volume_mounts) || nil
            }.compact
          end
        end
      end
    end
  end
end
