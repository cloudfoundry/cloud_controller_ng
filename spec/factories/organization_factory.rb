require 'models/runtime/organization'

FactoryBot.define do
  factory(:organization, class: VCAP::CloudController::Organization) do
    name
    quota_definition
    status { 'active' }
  end
end
