module VCAP::CloudController
  class InstallBuildpacks

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def install(buildpacks)
      return unless buildpacks
      
      buildpacks.each do |bpack|
        buildpack = VCAP.symbolize_keys(bpack)

        buildpack_name = buildpack.delete(:name)
        if buildpack_name.nil?
          logger.error "A name must be specified for the buildpack: #{buildpack}"
          next
        end

        package = buildpack.delete(:package)
        buildpack_file = buildpack.delete(:file)
        if package.nil? && buildpack_file.nil?
          logger.error "A package or file must be specified for the buildpack: #{bpack}"
          next
        end

        buildpack_file = buildpack_zip(package, buildpack_file)
        if buildpack_file.nil?
          logger.error "No file found for the buildpack: #{bpack}"
          next
        elsif !File.file?(buildpack_file)
          logger.error "File not found: #{buildpack_file}, for the buildpack: #{bpack}"
          next
        end

        buildpack_job = VCAP::CloudController::Jobs::Runtime::BuildpackInstaller.new(buildpack_name, buildpack_file, buildpack)
        job = VCAP::CloudController::Jobs::Enqueuer.new(buildpack_job, queue: VCAP::CloudController::Jobs::LocalQueue.new(config)).enqueue()
      end
    end

    def logger
      @logger ||= Steno.logger("cc.install_buildpacks")
    end

    private

    def buildpack_zip(package, zipfile)
      return zipfile if zipfile
      job_dir = File.join('/var/vcap/packages', package, '*.zip')
      Dir[job_dir].first
    end

  end
end
