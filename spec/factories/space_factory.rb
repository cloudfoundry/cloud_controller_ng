require 'models/runtime/space'
require_relative './sequences'

FactoryBot.define do
  factory(:space, class: VCAP::CloudController::Space) do
    to_create(&:save)

    name
    organization

    transient do
      security_groups { [] }
      staging_security_groups { [] }
    end

    # https://github.com/jeremyevans/sequel#associations
    # many_to_many relationships only have an add_x method as a setter
    after(:create) do |space, evaluator|
      evaluator.security_groups.each do |security_group|
        space.add_security_group(security_group)
      end

      evaluator.staging_security_groups.each do |staging_security_group|
        space.add_staging_security_group(staging_security_group)
      end
    end
  end
end
