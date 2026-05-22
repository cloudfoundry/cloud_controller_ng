FactoryBot.define do
  factory :test_model, class: 'VCAP::CloudController::TestModel' do
    required_attr { true }
  end
end
