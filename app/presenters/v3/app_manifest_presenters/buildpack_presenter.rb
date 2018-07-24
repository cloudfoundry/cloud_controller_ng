module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class BuildpackPresenter
          def to_hash(app:, **_)
            return {} if app.docker?
            {
              buildpacks: app.lifecycle_data.buildpacks.presence,
              stack: app.lifecycle_data.stack,
            }
          end
        end
      end
    end
  end
end
