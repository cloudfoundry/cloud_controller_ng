module VCAP::CloudController
  class DropletCreate
    def create_docker_droplet(build)
      droplet = droplet_from_build(build)
      droplet.save

      Steno.logger('build_completed').info("droplet created: #{droplet.guid}")
      droplet
    end

    def create_buildpack_droplet(build)
      droplet = droplet_from_build(build)

      DropletModel.db.transaction do
        droplet.save
        droplet.buildpack_lifecycle_data = build.buildpack_lifecycle_data
      end

      droplet.reload
      Steno.logger('build_completed').info("droplet created: #{droplet.guid}")
      droplet
    end

    private

    def droplet_from_build(build)
      DropletModel.new(
        app_guid:             build.app.guid,
        package_guid:         build.package.guid,
        state:                DropletModel::STAGING_STATE,
        build:                build,
      )
    end
  end
end
