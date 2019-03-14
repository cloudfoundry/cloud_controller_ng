require 'models/request_count'

FactoryBot.define do
  factory :request_count, class: VCAP::CloudController::RequestCount do
    valid_until { Time.now.utc }
  end
end
