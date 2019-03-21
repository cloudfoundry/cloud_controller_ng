require 'models/runtime/stack'
require_relative './sequences'

FactoryBot.define do
  factory :stack, class: VCAP::CloudController::Stack do
    name
    description
  end
end
