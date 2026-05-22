FactoryBot.define do
  factory :isolation_segment_model, class: 'VCAP::CloudController::IsolationSegmentModel' do
    guid { generate(:guid) }
    name { generate(:name) }
  end
end
