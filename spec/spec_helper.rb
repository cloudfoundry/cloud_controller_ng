$:.unshift(File.expand_path("../../lib", __FILE__))
$:.unshift(File.expand_path("../../app", __FILE__))

require "rubygems"
require "bundler"
require "bundler/setup"

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

VCAP::CloudController::SpecBootstrap.init

Dir[File.expand_path("support/**/*.rb", File.dirname(__FILE__))].each { |file| require file }

RSpec.configure do |rspec_config|
  rspec_config.treat_symbols_as_metadata_keys_with_true_values = true

  rspec_config.include Rack::Test::Methods
  rspec_config.include ModelCreation
  rspec_config.extend ModelCreation

  rspec_config.include ControllerHelpers, type: :controller, :example_group => {
      :file_path => EscapedPath.join(%w[spec unit controllers])
  }

  rspec_config.include ControllerHelpers, type: :api, :example_group => {
      :file_path => EscapedPath.join(%w[spec api])
  }

  rspec_config.include ControllerHelpers, type: :acceptance, :example_group => {
      :file_path => EscapedPath.join(%w[spec acceptance])
  }

  rspec_config.include ApiDsl, type: :api, :example_group => {
      :file_path => EscapedPath.join(%w[spec api])
  }

  rspec_config.expose_current_running_example_as :example # Can be removed when we upgrade to rspec 3
  rspec_config.before :all do
    VCAP::CloudController::SecurityContext.clear

    RspecApiDocumentation.configure do |c|
      c.format = [:html, :json]
      c.api_name = "Cloud Foundry API"
      c.template_path = "spec/api/documentation/templates"
      c.curl_host = "https://api.[your-domain.com]"
      c.app = FakeFrontController.new(TestConfig.config)
    end
  end

  rspec_config.before :each do
    Fog::Mock.reset
    Sequel::Deprecation.output = StringIO.new
    Sequel::Deprecation.backtrace_filter = 5

    TestConfig.reset
  end

  rspec_config.around :each do |example|
    isolation = DatabaseIsolation.choose(example.metadata[:isolation], TestConfig.config, DbConfig.connection)
    tables = Tables.new(DbConfig.connection, DatabaseIsolation.isolated_tables(DbConfig.connection))
    expect {
      isolation.cleanly { example.run }
    }.not_to change { tables.counts }
  end

  rspec_config.after :each do
    expect(Sequel::Deprecation.output.string).to eq ''
    Sequel::Deprecation.output.close unless Sequel::Deprecation.output.closed?
  end

  rspec_config.after :all do
    TmpdirCleaner.clean
  end
end
