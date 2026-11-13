require 'presenters/helpers/censorship'

module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class BuildpackPresenter
          def to_hash(app:, **_)
            return {} if app.docker?

            {
              buildpacks: app.lifecycle_data.obfuscated_buildpacks.presence,
              stack: app.lifecycle_data.stack,
              credentials: app.lifecycle_data.credentials.nil? ? nil : Presenters::Censorship::REDACTED_CREDENTIAL
            }
          end
        end
      end
    end
  end
end
