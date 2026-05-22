FactoryBot.define do
  factory :isolation_segment_label_model, class: 'VCAP::CloudController::IsolationSegmentLabelModel' do
    guid { generate(:guid) }
  end
end
