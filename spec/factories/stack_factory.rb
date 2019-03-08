require 'models/runtime/stack'

FactoryBot.define do
  factory :stack, class: VCAP::CloudController::Stack do
    to_create(&:save)

    name
    description
  end
end
