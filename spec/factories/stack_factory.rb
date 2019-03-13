require 'models/runtime/stack'

FactoryBot.define do
  factory :stack, class: VCAP::CloudController::Stack do
    name
    description
  end
end
