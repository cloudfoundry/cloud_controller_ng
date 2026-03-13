$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'app')))
$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'lib')))

require 'active_support/all'
require 'active_model'
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

# errors_on helper from rspec-collection_matchers gem
# Enables: expect(message.errors_on(:attribute)).to include("error message")
# This extension is added when ActiveModel::Validations is loaded
if defined?(ActiveModel::Validations)
  module ::ActiveModel::Validations
    def errors_on(attribute, options={})
      valid_args = [options[:context]].compact
      valid?(*valid_args)

      [errors[attribute]].flatten.compact
    end

    alias_method :error_on, :errors_on
  end
end
