FactoryBot.define do
  factory :droplet_annotation_model, class: 'VCAP::CloudController::DropletAnnotationModel' do
    guid { generate(:guid) }
  end
end
