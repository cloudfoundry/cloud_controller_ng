FactoryBot.define do
  factory :droplet_label_model, class: 'VCAP::CloudController::DropletLabelModel' do
    guid { generate(:guid) }
  end
end
