require 'models/runtime/stack'
require_relative './sequences'

FactoryBot.define do
  factory :stack, class: VCAP::CloudController::Stack do
    to_create(&:save)

    name
    description
  end
end
