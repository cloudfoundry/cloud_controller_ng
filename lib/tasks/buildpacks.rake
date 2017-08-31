namespace :buildpacks do
  desc 'Install/Update buildpacks'
  task :install do
    buildpacks = RakeConfig.config.get(:install_buildpacks)
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment do
      VCAP::CloudController::InstallBuildpacks.new(RakeConfig.config).install(buildpacks)
    end
  end
end
