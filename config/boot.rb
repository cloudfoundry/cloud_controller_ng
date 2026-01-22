ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../app', __dir__))
$LOAD_PATH.unshift(File.expand_path('../middleware', __dir__))

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Speed up boot time by caching require calls
if ENV.fetch('DISABLE_BOOTSNAP', nil).nil?
  begin
    require 'bootsnap'
    Bootsnap.setup(
      cache_dir: File.join(__dir__, '..', 'tmp', 'cache'),
      development_mode: ENV.fetch('RAILS_ENV', 'development') != 'production',
      load_path_cache: true,
      compile_cache_iseq: true,
      compile_cache_yaml: true
    )
  rescue LoadError
    # bootsnap is optional, continue without it
  end
end
