require 'factory_bot'

RSpec.configure do |config|
  config.before(:suite) do
    FactoryBot.find_definitions

    FactoryBot.define do
      # Sequel uses #save instead of ActiveRecord's #save!
      to_create(&:save)

      sequence :description do |index|
        "desc-#{index}"
      end

      sequence :name do |index|
        "name-#{index}"
      end

      sequence :guid do
        "guid-#{SecureRandom.uuid}"
      end
    end
  end
end
