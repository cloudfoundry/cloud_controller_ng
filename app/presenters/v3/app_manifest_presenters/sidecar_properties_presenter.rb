module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class SidecarPropertiesPresenter
          def to_hash(app:, **_)
            sidecars = app.sidecars.sort_by(&:name).map { |sidecar| sidecar_hash(sidecar) }
            { sidecars: sidecars.presence }
          end

          def sidecar_hash(sidecar)
            {
              'name' => sidecar.name,
              'process_types' => sidecar.process_types,
              'command' => sidecar.command,
            }
          end
        end
      end
    end
  end
end
