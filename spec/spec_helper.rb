SPEC_HELPER_LOADED = true
require 'rubygems'

begin
  require 'spork'
  # uncomment the following line to use spork with the debugger
  # require 'spork/ext/ruby-debug'

  run_spork = !`ps | grep spork | grep -v grep`.empty?
rescue LoadError
  run_spork = false
end

# --- Instructions ---
# Sort the contents of this file into a Spork.prefork and a Spork.each_run
# block.
#
# The Spork.prefork block is run only once when the spork server is started.
# You typically want to place most of your (slow) initializer code in here, in
# particular, require'ing any 3rd-party gems that you don't normally modify
# during development.
#
# The Spork.each_run block is run each time you run your specs.  In case you
# need to load files that tend to change during development, require them here.
# With Rails, your application modules are loaded automatically, so sometimes
# this block can remain empty.
#
# Note: You can modify files loaded *from* the Spork.each_run block without
# restarting the spork server.  However, this file itself will not be reloaded,
# so if you change any of the code inside the each_run block, you still need to
# restart the server.  In general, if you have non-trivial code in this file,
# it's advisable to move it into a separate file so you can easily edit it
# without restarting spork.  (For example, with RSpec, you could move
# non-trivial code into a file spec/support/my_helper.rb, making sure that the
# spec/support/* files are require'd from inside the each_run block.)
#
# Any code that is left outside the two blocks will be run during preforking
# *and* during each_run -- that's probably not what you want.
#
# These instructions should self-destruct in 10 seconds.  If they don't, feel
# free to delete them.

init_block = proc do
  $LOAD_PATH.push(File.expand_path(__dir__))

  require File.expand_path('../config/boot', __dir__)

  if ENV['COVERAGE']
    require 'simplecov'
    SimpleCov.start do
      add_filter '/spec/'
      add_filter '/errors/'
      add_filter '/docs/'
    end
  end
  ENV['PB_IGNORE_DEPRECATIONS'] = 'true'
  ENV['RAILS_ENV'] ||= 'test'

  require 'machinist/sequel'
  require 'machinist/object'
  require 'rack/test'
  require 'timecop'
  require 'awesome_print'

  require 'steno'
  require 'webmock/rspec'

  require 'pry'

  require 'cloud_controller'
  require 'allowy/rspec'

  require 'posix/spawn'

  require 'rspec_api_documentation'
  require 'services'

  require 'support/bootstrap/spec_bootstrap'
  require 'rspec/collection_matchers'
  require 'rspec/its'
  require 'rspec/wait'
end

each_run_block = proc do
  # Moving this line into the init-block means that changes in code files aren't detected.
  VCAP::CloudController::SpecBootstrap.init

  Dir[File.expand_path('support/**/*.rb', File.dirname(__FILE__))].sort.each { |file| require file }

  # each-run here?
  RSpec.configure do |rspec_config|
    rspec_config.mock_with :rspec do |mocks|
      mocks.verify_partial_doubles = true
    end
    rspec_config.filter_run_excluding :opi, :perm, :stepper
    rspec_config.expose_dsl_globally = false
    rspec_config.backtrace_exclusion_patterns = [%r{/gems/}, %r{/bin/rspec}]

    rspec_config.expect_with(:rspec) do |config|
      config.syntax = :expect
      config.max_formatted_output_length = 1000
    end
    rspec_config.extend DeprecationHelpers
    rspec_config.include Rack::Test::Methods
    rspec_config.include ModelCreation
    rspec_config.include TimeHelpers
    rspec_config.include LinkHelpers
    rspec_config.include BackgroundJobHelpers

    rspec_config.include ServiceBrokerHelpers
    rspec_config.include UserHelpers
    rspec_config.include UserHeaderHelpers
    rspec_config.include ControllerHelpers, type: :v2_controller, file_path: EscapedPath.join(%w(spec unit controllers))
    rspec_config.include ControllerHelpers, type: :api
    rspec_config.include ControllerHelpers, file_path: EscapedPath.join(%w(spec acceptance))
    rspec_config.include RequestSpecHelper, file_path: EscapedPath.join(%w(spec acceptance))
    rspec_config.include ControllerHelpers, file_path: EscapedPath.join(%w(spec request))
    rspec_config.include RequestSpecHelper, file_path: EscapedPath.join(%w(spec request))
    rspec_config.include LifecycleSpecHelper, file_path: EscapedPath.join(%w(spec request lifecycle))
    rspec_config.include ApiDsl, type: :api
    rspec_config.include LegacyApiDsl, type: :legacy_api

    rspec_config.include IntegrationHelpers, type: :integration
    rspec_config.include IntegrationHttp, type: :integration
    rspec_config.include IntegrationSetupHelpers, type: :integration
    rspec_config.include IntegrationSetup, type: :integration

    rspec_config.include SpaceRestrictedResponseGenerators

    rspec_config.before(:all) { WebMock.disable_net_connect!(allow: 'codeclimate.com') }
    rspec_config.before(:all, type: :integration) do
      WebMock.allow_net_connect!
      @uaa_server = FakeUAAServer.new(6789)
      @uaa_server.start
    end
    rspec_config.after(:all, type: :integration) do
      WebMock.disable_net_connect!(allow: 'codeclimate.com')
      @uaa_server.stop
    end

    rspec_config.before(:example, :log_db) do
      db = DbConfig.new.connection
      db.loggers << Logger.new($stdout)
      db.sql_log_level = :info
    end

    rspec_config.example_status_persistence_file_path = 'spec/examples.txt'
    rspec_config.expose_current_running_example_as :example # Can be removed when we upgrade to rspec 3

    rspec_config.before :suite do
      VCAP::CloudController::SpecBootstrap.seed
    end

    rspec_config.before :each do
      Fog::Mock.reset

      if Fog.mock?
        CloudController::DependencyLocator.instance.droplet_blobstore.ensure_bucket_exists
        CloudController::DependencyLocator.instance.package_blobstore.ensure_bucket_exists
        CloudController::DependencyLocator.instance.global_app_bits_cache.ensure_bucket_exists
        CloudController::DependencyLocator.instance.buildpack_blobstore.ensure_bucket_exists
      end

      Delayed::Worker.destroy_failed_jobs = false
      Sequel::Deprecation.output = StringIO.new
      Sequel::Deprecation.backtrace_filter = 5

      TestConfig.context = example.metadata[:job_context] || :api
      TestConfig.reset

      VCAP::CloudController::SecurityContext.clear
      allow_any_instance_of(VCAP::CloudController::UaaTokenDecoder).to receive(:uaa_issuer).and_return(UAAIssuer::ISSUER)
    end

    rspec_config.around :each do |example|
      # DatabaseIsolation requires the api config context
      TestConfig.context = :api
      TestConfig.reset

      isolation = DatabaseIsolation.choose(example.metadata[:isolation], TestConfig.config_instance, DbConfig.new.connection)
      isolation.cleanly { example.run }
    end

    rspec_config.after :each do
      unless Sequel::Deprecation.output.string == ''
        raise "Sequel Deprecation String found: #{Sequel::Deprecation.output.string}"
      end

      Sequel::Deprecation.output.close unless Sequel::Deprecation.output.closed?
    end

    rspec_config.after :all do
      TmpdirCleaner.clean
    end

    rspec_config.after :each do
      Timecop.return
    end

    rspec_config.after(:each, type: :legacy_api) { add_deprecation_warning }

    RspecApiDocumentation.configure do |c|
      c.app = VCAP::CloudController::RackAppBuilder.new.build(TestConfig.config_instance, VCAP::CloudController::Metrics::RequestMetrics.new)
      c.format = [:html, :json]
      c.api_name = 'Cloud Foundry API'
      c.template_path = 'spec/api/documentation/templates'
      c.curl_host = 'https://api.[your-domain.com]'
    end
  end
end

if run_spork
  Spork.prefork do
    # Loading more in this block will cause your tests to run faster. However,
    # if you change any configuration or code from libraries loaded here, you'll
    # need to restart spork for it to take effect.
    init_block.call
  end
  Spork.each_run do
    # This code will be run each time you run your specs.
    each_run_block.call
  end
else
  init_block.call
  each_run_block.call
end
