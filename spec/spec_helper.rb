$:.unshift(File.expand_path("../../lib", __FILE__))
$:.unshift(File.expand_path("../../app", __FILE__))

require "rubygems"
require "bundler"
require "bundler/setup"

if ENV["CODECLIMATE_REPO_TOKEN"] && ENV["COVERAGE"]
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
end

require "fakefs/safe"
require "machinist/sequel"
require "machinist/object"
require "rack/test"
require "timecop"

require "steno"
require "webmock/rspec"
require "cf_message_bus/mock_message_bus"

require "cloud_controller"
require "allowy/rspec"

require "pry"
require "posix/spawn"

require "rspec_api_documentation"
require "services"

require "support/bootstrap/spec_bootstrap"
require "rspec/collection_matchers"
require "rspec/its"

VCAP::CloudController::SpecBootstrap.init

Dir[File.expand_path("support/**/*.rb", File.dirname(__FILE__))].each { |file| require file }

RSpec.configure do |rspec_config|
  rspec_config.expect_with(:rspec) { |config| config.syntax = :expect }
  rspec_config.include Rack::Test::Methods
  rspec_config.include ModelCreation

  rspec_config.include ServiceBrokerHelpers
  rspec_config.include ControllerHelpers, type: :controller, :file_path => EscapedPath.join(%w[spec unit controllers])
  rspec_config.include ControllerHelpers, type: :api
  rspec_config.include ControllerHelpers, :file_path => EscapedPath.join(%w[spec acceptance])
  rspec_config.include ApiDsl, type: :api

  rspec_config.include IntegrationHelpers, type: :integration
  rspec_config.include IntegrationHttp, type: :integration
  rspec_config.include IntegrationSetupHelpers, type: :integration
  rspec_config.include IntegrationSetup, type: :integration

  rspec_config.before(:all) { WebMock.disable_net_connect!(:allow => "codeclimate.com") }
  rspec_config.before(:all, type: :integration) { WebMock.allow_net_connect! }
  rspec_config.after(:all, type: :integration) { WebMock.disable_net_connect!(:allow => "codeclimate.com") }

  rspec_config.expose_current_running_example_as :example # Can be removed when we upgrade to rspec 3

  rspec_config.before :each do
    Fog::Mock.reset
    Sequel::Deprecation.output = StringIO.new
    Sequel::Deprecation.backtrace_filter = 5

    TestConfig.reset

    stub_v1_broker
    VCAP::CloudController::SecurityContext.clear
  end

  rspec_config.around :each do |example|
    isolation = DatabaseIsolation.choose(example.metadata[:isolation], TestConfig.config, DbConfig.connection)
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


  rspec_config.after(:each, type: :api) { add_deprecation_warning }

  RspecApiDocumentation.configure do |c|
    c.format = [:html, :json]
    c.api_name = "Cloud Foundry API"
    c.template_path = "spec/api/documentation/templates"
    c.curl_host = "https://api.[your-domain.com]"
    c.app = FakeFrontController.new(TestConfig.config)
  end
end
