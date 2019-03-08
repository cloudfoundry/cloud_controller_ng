require 'models/runtime/user'

FactoryBot.define do
  sequence :uaa_id do |index|
    "uaa-id-#{index}"
  end

  factory :user, class: VCAP::CloudController::User do
    to_create(&:save)

    guid { generate(:uaa_id) }
  end
end
