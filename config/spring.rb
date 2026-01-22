Spring.application_root = File.expand_path('..', __dir__)

# Files that should trigger a restart when changed
Spring.watch(
  '.ruby-version',
  'Gemfile',
  'Gemfile.lock',
  'config/cloud_controller.yml'
)

# Directories to watch for changes
%w[
  lib
  app
  config
  spec/support
].each do |path|
  Spring.watch(path)
end
