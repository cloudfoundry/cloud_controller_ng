require 'models/runtime/isolation_segment_model'

FactoryBot.define do
  factory :isolation_segment, class: VCAP::CloudController::IsolationSegmentModel do
    name
    guid
  end
end
