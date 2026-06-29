FactoryBot.define do
  factory :isolation_segment_annotation_model, class: 'VCAP::CloudController::IsolationSegmentAnnotationModel' do
    guid { generate(:guid) }
  end
end
