require File.expand_path('../../config/boot', __FILE__)

if ENV['CODECLIMATE_REPO_TOKEN'] && ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter '/docs/'
  end
end
ENV['PB_IGNORE_DEPRECATIONS'] = 'true'

require 'fakefs/safe'
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

VCAP::CloudController::SpecBootstrap.init

Dir[File.expand_path('support/**/*.rb', File.dirname(__FILE__))].each { |file| require file }

RSpec.configure do |rspec_config|
  rspec_config.expose_dsl_globally = false
  rspec_config.backtrace_exclusion_patterns = [%r{/gems/}, %r{/bin/rspec}]

  rspec_config.expect_with(:rspec) { |config| config.syntax = :expect }
  rspec_config.extend DeprecationHelpers
  rspec_config.include Rack::Test::Methods
  rspec_config.include ModelCreation
  rspec_config.include TimeHelpers
  rspec_config.include LinkHelpers
  rspec_config.include BackgroundJobHelpers

  rspec_config.include ServiceBrokerHelpers
  rspec_config.include UserHelpers
  rspec_config.include ControllerHelpers, type: :v2_controller, file_path: EscapedPath.join(%w(spec unit controllers))
  rspec_config.include ControllerHelpers, type: :api
  rspec_config.include ControllerHelpers, file_path: EscapedPath.join(%w(spec acceptance))
  rspec_config.include RequestSpecHelper, file_path: EscapedPath.join(%w(spec acceptance))
  rspec_config.include ControllerHelpers, file_path: EscapedPath.join(%w(spec request))
  rspec_config.include RequestSpecHelper, file_path: EscapedPath.join(%w(spec request))
  rspec_config.include ApiDsl, type: :api
  rspec_config.include LegacyApiDsl, type: :legacy_api

  rspec_config.include IntegrationHelpers, type: :integration
  rspec_config.include IntegrationHttp, type: :integration
  rspec_config.include IntegrationSetupHelpers, type: :integration
  rspec_config.include IntegrationSetup, type: :integration

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

  rspec_config.example_status_persistence_file_path = 'spec/examples.txt'
  rspec_config.expose_current_running_example_as :example # Can be removed when we upgrade to rspec 3

  rspec_config.before :suite do
    VCAP::CloudController::SpecBootstrap.seed
  end

  rspec_config.before :each do
    Fog::Mock.reset
    Delayed::Worker.destroy_failed_jobs = false
    Sequel::Deprecation.output = StringIO.new
    Sequel::Deprecation.backtrace_filter = 5

    TestConfig.reset

    VCAP::CloudController::SecurityContext.clear
    allow_any_instance_of(VCAP::CloudController::UaaTokenDecoder).to receive(:uaa_issuer).and_return(nil)
  end

  rspec_config.around :each do |example|
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
