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
            buildpack = Buildpack.update(buildpack, values)
          else
            buildpack = Buildpack.create(values)
          end

          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          upload_buildpack = UploadBuildpack.new(buildpack_blobstore)
          upload_buildpack.upload_bits(buildpack, file, File.basename(file))

          if opts.key?(:locked)
            Buildpack.update(buildpack, { locked: opts[:locked] })
          end

          logger.info "Buildpack #{name} installed or updated"
        end

        def job_name_in_configuration
          :buildpack_installer
        end
      end
    end
  end
end
