FactoryBot.define do
  factory :domain_annotation_model, class: 'VCAP::CloudController::DomainAnnotationModel' do
    guid { generate(:guid) }
  end
end
