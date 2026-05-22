FactoryBot.define do
  factory :route, class: 'VCAP::CloudController::Route' do
    transient do
      organization { nil }
    end

    space { association(:space, organization: organization || association(:organization)) }
    domain { association(:private_domain, owning_organization: space.organization) }
    host { generate(:host) }

    trait :tcp do
      domain { association(:shared_domain, :tcp) }
      port { generate(:port) }
      host { '' }
    end
  end
end
