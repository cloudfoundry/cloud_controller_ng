module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstaller < Struct.new(:name, :file, :opts, :config)
        def perform
          logger = Steno.logger("cc.background")
          logger.info "Installing buildpack #{name}"

          buildpack = Buildpack.find(name: name)
          if buildpack.nil?
            buildpack = Buildpack.create(name: name)
            created = true
          elsif buildpack.locked
            logger.info "Buildpack #{name} locked, not updated"
            return
          end

          begin
            buildpack_uploader.upload_buildpack(buildpack, file, File.basename(file))
          rescue => e
            if created
              buildpack.destroy
            end
            raise e
          end

          buildpack.update(opts)
          logger.info "Buildpack #{name} installed or updated"
        rescue => e
          logger.error("Buildpack #{name} failed to install or update. Error: #{e.inspect}")
          raise e
        end

        def max_attempts
          1
        end

        def job_name_in_configuration
          :buildpack_installer
        end

        def buildpack_uploader
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          UploadBuildpack.new(buildpack_blobstore)
        end
      end
    end
  end
end
