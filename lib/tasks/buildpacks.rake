namespace :buildpacks do

  desc "Install/Update buildpacks"
  task :install do
    buildpacks = config[:install_buildpacks]
    BackgroundJobEnvironment.new(config).setup_environment
    VCAP::CloudController::InstallBuildpacks.new(config).install(buildpacks)
  end
end
