module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstaller < Struct.new(:name, :file, :opts, :config)

        def perform
          logger = Steno.logger("cc.background")
          logger.info "Installing buildpack #{name}"

          buildpack = Buildpack.find(:name=> name)
          if buildpack && buildpack.locked
            logger.info "Buildpack #{name} is locked, update stopped"
            return
          end

          self.opts ||= {}
          values = opts.merge(name: name)
          values.delete(:locked)

          if buildpack
            Buildpack.db.transaction do
              buildpack.lock!
              buildpack.update(values)
            end
          else
            buildpack = Buildpack.create(values)
          end

          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          upload_buildpack = UploadBuildpack.new(buildpack_blobstore)
          upload_buildpack.upload_bits(buildpack, file, File.basename(file))

          if opts.key?(:locked)
            buildpack.update({ locked: opts[:locked] })
          end

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
      end
    end
  end
end
