module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class NameEnvPresenter
          def to_hash(app:, **_)
            {
              name: app.name,
              env: app.environment_variables.presence,
            }
          end
        end
      end
    end
  end
end
