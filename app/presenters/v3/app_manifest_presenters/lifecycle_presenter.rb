module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class LifecyclePresenter
          def to_hash(app:, **_)
            {
              lifecycle: app.lifecycle_type
            }
          end
        end
      end
    end
  end
end
