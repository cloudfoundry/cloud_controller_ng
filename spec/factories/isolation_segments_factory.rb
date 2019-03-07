require 'models/runtime/isolation_segment_model'

FactoryBot.define do
  sequence :name do |n|
    "name-#{n}"
  end

  sequence :guid do
    "guid-#{SecureRandom.uuid}"
  end

  factory :isolation_segment, class: VCAP::CloudController::IsolationSegmentModel do
    to_create(&:save)

    name
    guid
  end
end
