require 'models/runtime/isolation_segment_model'

FactoryBot.define do
  factory :isolation_segment, class: VCAP::CloudController::IsolationSegmentModel do
    to_create(&:save)

    name
    guid
  end
end
