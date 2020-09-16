$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'app')))
$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'lib')))

require 'active_support/all'

# So that specs using this helper don't fail with undefined constant error
module VCAP
  module CloudController
  end
end

class StubConfig
  def self.prepare(example, **data)
    config = new(data)
    example.allow(TestConfig).to example.receive(:config).and_return(config)
    example.allow(VCAP::CloudController::Config).to example.receive(:config).and_return(config)
  end

  def initialize(data)
    @data = data
  end

  def get(key)
    data[key]
  end

  alias_method :[], :get

  private

  attr_reader :data
end

RSpec.configure do |rspec_config|
  rspec_config.expose_dsl_globally = false
end
