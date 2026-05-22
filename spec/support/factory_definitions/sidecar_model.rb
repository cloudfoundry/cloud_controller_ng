FactoryBot.define do
  factory :sidecar_model, class: 'VCAP::CloudController::SidecarModel' do
    name    { generate(:name) }
    command { 'bundle exec rackup' }
    association :app, factory: :app_model
    origin { VCAP::CloudController::SidecarModel::ORIGIN_USER }
  end
end
