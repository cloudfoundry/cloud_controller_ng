ENV['RAILS_ENV'] ||= 'test'

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
$LOAD_PATH.unshift(File.expand_path('../../app', __FILE__))
$LOAD_PATH.unshift(File.expand_path('../../middleware', __FILE__))

require 'rubygems'
require 'bundler'
require 'bundler/setup'

if ENV['CODECLIMATE_REPO_TOKEN'] && ENV['COVERAGE']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
end

require 'fakefs/safe'
require 'machinist/sequel'
require 'machinist/object'
require 'timecop'

require 'steno'
require 'cf_message_bus/mock_message_bus'

require 'cloud_controller'
require 'allowy/rspec'

require 'posix/spawn'

require 'rspec_api_documentation'
require 'services'

require 'support/bootstrap/spec_bootstrap'
require 'rspec/collection_matchers'
require 'rspec/its'
require 'rspec/rails'

VCAP::CloudController::SpecBootstrap.init

Dir[File.expand_path('support/**/*.rb', File.dirname(__FILE__))].each { |file| require file }

RSpec.configure do |rspec_config|
  rspec_config.expect_with(:rspec) { |config| config.syntax = :expect }
  # rspec_config.include Rack::Test::Methods
  rspec_config.include ModelCreation

  rspec_config.include ServiceBrokerHelpers
  rspec_config.include ControllerHelpers, type: :controller_helpers, file_path: EscapedPath.join(%w(spec unit controllers))
  rspec_config.include ControllerHelpers, type: :api
  rspec_config.include ControllerHelpers, file_path: EscapedPath.join(%w(spec acceptance))
  rspec_config.include ApiDsl, type: :api
  rspec_config.include LegacyApiDsl, type: :legacy_api

  rspec_config.include IntegrationHelpers, type: :integration
  rspec_config.include IntegrationHttp, type: :integration
  rspec_config.include IntegrationSetupHelpers, type: :integration
  rspec_config.include IntegrationSetup, type: :integration

  rspec_config.expose_current_running_example_as :example # Can be removed when we upgrade to rspec 3

  Delayed::Worker.plugins << DeserializationRetry

  rspec_config.before :each do
    Fog::Mock.reset
    Delayed::Worker.destroy_failed_jobs = false
    Sequel::Deprecation.output = StringIO.new
    Sequel::Deprecation.backtrace_filter = 5

    TestConfig.reset

    stub_v1_broker
    VCAP::CloudController::SecurityContext.clear
  end

  rspec_config.around :each do |example|
    isolation = DatabaseIsolation.choose(example.metadata[:isolation], TestConfig.config, DbConfig.new.connection)
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
    c.format = [:html, :json]
    c.api_name = 'Cloud Foundry API'
    c.template_path = 'spec/api/documentation/templates'
    c.curl_host = 'https://api.[your-domain.com]'
    c.app = Rails.application.app
  end
end
