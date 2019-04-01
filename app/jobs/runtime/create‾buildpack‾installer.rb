module VCAP::CloudController
  module Jobs
    module Runtime
      class CreateBuildpackInstaller < BuildpackInstaller
        def perform
          logger.info "Installing buildpack name `#{name}' with stack `#{stack_name}'"

          buildpack = nil

          buildpacks_lock = Locking[name: 'buildpacks']
          buildpacks_lock.db.transaction do
            buildpacks_lock.lock!
            buildpack = Buildpack.create(name: name, stack: stack_name)
          end
          begin
            buildpack_uploader.upload_buildpack(buildpack, file, File.basename(file))
          rescue
            buildpack.destroy
            raise
          end
          buildpack.update(options)

          logger.info "Buildpack #{name} created and installed"
        rescue => e
          logger.error("Buildpack #{name} failed to install or update. Error: #{e.inspect}")
          raise e
        end
      end
    end
  end
end
