require 'models/runtime/feature_flag'

FactoryBot.define do
  factory(:feature_flag, class: VCAP::CloudController::FeatureFlag) do
    name { 'user_org_creation' }
    enabled { false }
    error_message
  end
end
