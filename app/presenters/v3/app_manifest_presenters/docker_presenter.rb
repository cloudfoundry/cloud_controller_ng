module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class DockerPresenter
          def to_hash(app:, **_)
            return {} unless app.docker?
            return {} unless app.current_package
            {
              docker: {
                image: app.current_package.image,
                username: app.current_package.docker_username
              }.compact
            }
          end
        end
      end
    end
  end
end
