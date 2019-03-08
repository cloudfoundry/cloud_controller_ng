require 'models/runtime/organization'

FactoryBot.define do
  factory(:organization, class: VCAP::CloudController::Organization) do
    to_create(&:save)

    name
    quota_definition
    status { 'active' }

    transient do
      users { [] }
    end

    after(:create) do |organization, evaluator|
      evaluator.users.each { |u| organization.add_user(u) }
    end
  end
end
