require 'factory_bot'

RSpec.configure do |config|
  config.before(:suite) do
    FactoryBot.find_definitions
  end
end
