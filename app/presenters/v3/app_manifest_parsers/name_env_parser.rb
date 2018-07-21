module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestParsers
        class NameEnvParser
          def parse(app, _, _)
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
