module VCAP::CloudController
  module Jobs
    module Runtime
      class CreateBuildpackInstaller < BuildpackInstaller
        attr_accessor :config_index

        def initialize(job_options)
          super
          @config_index = job_options[:config_index]
        end

        def perform
          logger.info "Installing buildpack name `#{name}' with stack `#{stack_name}'"

          buildpack = nil

          buildpacks_lock = Locking[name: 'buildpacks']
          buildpacks_lock.db.transaction do
            buildpacks_lock.lock!
            buildpack = Buildpack.create(name: name, stack: stack_name, lifecycle: options[:lifecycle])
            buildpack.move_to(config_index + 1) if !config_index.nil? && !options.key?(:position)
          end
          begin
            buildpack_uploader.upload_buildpack(buildpack, file, File.basename(file))
          rescue StandardError
            buildpack.destroy
            raise
          end
          buildpack.update(options)

          logger.info "Buildpack #{name} created and installed"
        rescue StandardError => e
          logger.error("Buildpack #{name} failed to install or update. Error: #{e.class} - #{e.message}")
          raise e
        end
      end
    end
  end
end
