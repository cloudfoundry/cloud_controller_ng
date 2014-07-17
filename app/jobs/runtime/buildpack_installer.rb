module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstaller < Struct.new(:name, :file, :opts, :config)

        def perform
          logger = Steno.logger("cc.background")
          logger.info "Installing buildpack #{name}"

          self.opts ||= {}
          values    = opts.merge(name: name)

          buildpack = Buildpack.find(name: name)
          buildpack ||= Buildpack.new(name: name)

          if buildpack.locked
            logger.info "Buildpack #{name} is locked, update stopped"
            return
          end

          buildpack_uploader.upload_bits(buildpack, file, File.basename(file))

          Buildpack.db.transaction do
            buildpack.lock!
            buildpack.update(values)
          end

          logger.info "Buildpack #{name} installed or updated"
        rescue => e
          logger.error("Buildpack #{name} failed to install or update. Error: #{e.inspect} #{e.backtrace.join("\n")}")
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
