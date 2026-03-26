module VCAP::CloudController
  class InstallBuildpacks
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def install(buildpacks)
      return unless buildpacks

      CloudController::DependencyLocator.instance.buildpack_blobstore.ensure_bucket_exists
      job_factory = VCAP::CloudController::Jobs::Runtime::BuildpackInstallerFactory.new

      existing_count_by_lifecycle = {
        Lifecycles::BUILDPACK => Buildpack.where(lifecycle: Lifecycles::BUILDPACK).count,
        Lifecycles::CNB => Buildpack.where(lifecycle: Lifecycles::CNB).count
      }

      factory_options = []
      buildpacks.each do |bpack|
        opts = buildpack_factory_options(bpack, existing_count_by_lifecycle, factory_options)
        factory_options << opts if opts
      end

      buildpack_install_jobs = generate_install_jobs(factory_options, job_factory)

      buildpack_install_jobs.flatten!
      run_canary(buildpack_install_jobs)
      enqueue_remaining_jobs(buildpack_install_jobs)
    end

    def logger
      @logger ||= Steno.logger('cc.install_buildpacks')
    end

    private

    def buildpack_factory_options(bpack, existing_count_by_lifecycle, factory_options)
      buildpack_opts = bpack.deep_symbolize_keys
      buildpack_opts[:lifecycle] = Lifecycles::BUILDPACK if buildpack_opts[:lifecycle].nil?

      buildpack_name = buildpack_opts.delete(:name)
      if buildpack_name.nil?
        logger.error "A name must be specified for the buildpack_opts: #{buildpack_opts}"
        return
      end

      package = buildpack_opts.delete(:package)
      buildpack_file = buildpack_opts.delete(:file)
      if package.nil? && buildpack_file.nil?
        logger.error "A package or file must be specified for the buildpack_opts: #{bpack}"
        return
      end

      buildpack_file = buildpack_zip(package, buildpack_file)
      if buildpack_file.nil?
        logger.error "No file found for the buildpack_opts: #{bpack}"
        return
      elsif !File.file?(buildpack_file)
        logger.error "File not found: #{buildpack_file}, for the buildpack_opts: #{bpack}"
        return
      end

      lifecycle = buildpack_opts[:lifecycle]
      existing_offset = existing_count_by_lifecycle[lifecycle] || 0
      # exclude counting buildpacks with position because they don't need a config index
      unless buildpack_opts.key?(:position)
        config_index = existing_offset + factory_options.count do |opts|
          opts[:options][:lifecycle] == lifecycle && !opts[:options].key?(:position)
        end
      end

      { name: buildpack_name, file: buildpack_file, options: buildpack_opts, stack: detected_stack(buildpack_file, buildpack_opts),
        config_index: config_index }
    end

    def generate_install_jobs(factory_options, job_factory)
      buildpack_install_jobs = []
      buildpacks_by_lifecycle = factory_options.group_by { |options| options[:options][:lifecycle] }
      buildpacks_by_lifecycle.each_value do |options|
        options.group_by { |opts| opts[:name] }.each do |name, buildpack_options|
          buildpack_install_jobs << job_factory.plan(name, buildpack_options)
        end
      end
      buildpack_install_jobs
    end

    def detected_stack(file, opts)
      return opts[:stack] if opts[:lifecycle] == Lifecycles::CNB

      VCAP::CloudController::Buildpacks::StackNameExtractor.extract_from_file(file)
    end

    def buildpack_zip(package, zipfile)
      return zipfile if zipfile

      job_dir = File.join('/var/vcap/packages', package, '*[.zip|.cnb|.tgz|.tar.gz]')
      Dir[job_dir].first
    end

    def run_canary(jobs)
      jobs.first.perform if jobs.first
    end

    def enqueue_remaining_jobs(jobs)
      jobs.drop(1).each do |job|
        VCAP::CloudController::Jobs::Enqueuer.new(queue: VCAP::CloudController::Jobs::Queues.local(config)).enqueue(job)
      end
    end
  end
end
