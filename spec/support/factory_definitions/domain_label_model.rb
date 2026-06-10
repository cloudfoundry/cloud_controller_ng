FactoryBot.define do
  factory :domain_label_model, class: 'VCAP::CloudController::DomainLabelModel' do
    guid { generate(:guid) }
  end
end
