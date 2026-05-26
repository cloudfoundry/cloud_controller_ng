$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'app')))
$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'lib')))
$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'middleware')))

require 'active_support/all'
require 'active_model'
require 'rspec/its'
require 'pry'
# So that specs using this helper don't fail with undefined constant error
module VCAP
  module CloudController
    # Minimal Config stub for message validation specs
    # Only define if not already defined (avoid conflict with spec_helper)
    unless defined?(Config)
      class Config
        def self.config
          @config ||= new
        end

        def get(*_keys)
          nil
        end
      end
    end
  end
end

class StubConfig
  def self.prepare(example, **data)
    config = new(data)
    example.allow(TestConfig).to example.receive(:config).and_return(config) if defined?(TestConfig)
    example.allow(VCAP::CloudController::Config).to example.receive(:config).and_return(config)
  end

  def initialize(data)
    @data = data
  end

  def get(*keys)
    keys.inject(data) { |memo, key| memo.is_a?(Hash) ? memo[key] : nil }
  end

  alias_method :[], :get

  private

  attr_reader :data
end

RSpec.configure do |rspec_config|
  rspec_config.expose_dsl_globally = false

  rspec_config.before do
    if defined?(VCAP::CloudController::Config) && VCAP::CloudController::Config.config.nil?
      allow(VCAP::CloudController::Config).to receive(:config).and_return(StubConfig.new({}))
    end
  end
end
