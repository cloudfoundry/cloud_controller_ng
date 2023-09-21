module VCAP::CloudController
  module Jobs
    module Runtime
      class UpdateBuildpackInstaller < BuildpackInstaller
        def perform
          logger.info "Updating buildpack name `#{name}' with stack `#{stack_name}'"

          buildpack = Buildpack.find(guid: guid_to_upgrade)

          if buildpack.locked
            logger.info "Buildpack #{name} locked, not updated"
            return
          end

          begin
            buildpack_uploader.upload_buildpack(buildpack, file, File.basename(file))
          rescue StandardError
            raise
          end
          buildpack.update(options.merge(stack: stack_name))

          logger.info "Buildpack #{name} updated"
        rescue StandardError => e
          logger.error("Buildpack #{name} failed to update. Error: #{e.inspect}")
          raise
        end
      end
    end
  end
end
