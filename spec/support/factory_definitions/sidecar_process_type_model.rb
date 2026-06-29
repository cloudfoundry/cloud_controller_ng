FactoryBot.define do
  factory :sidecar_process_type_model, class: 'VCAP::CloudController::SidecarProcessTypeModel' do
    type { 'web' }
    association :sidecar, factory: :sidecar_model
    app_guid { sidecar.app_guid }
  end
end
