FactoryBot.define do
  factory :route_annotation_model, class: 'VCAP::CloudController::RouteAnnotationModel' do
    guid { generate(:guid) }
  end
end
