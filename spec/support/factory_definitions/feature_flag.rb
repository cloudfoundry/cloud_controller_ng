FactoryBot.define do
  factory :feature_flag, class: 'VCAP::CloudController::FeatureFlag' do
    name { generate(:feature_flag_name) }
    enabled { false }
    error_message { nil }
  end
end
