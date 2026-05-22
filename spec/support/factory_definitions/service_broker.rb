FactoryBot.define do
  factory :service_broker, class: 'VCAP::CloudController::ServiceBroker' do
    name          { generate(:name) }
    broker_url    { generate(:url) }
    state         { VCAP::CloudController::ServiceBrokerStateEnum::AVAILABLE }
    auth_username { generate(:auth_username) }
    auth_password { generate(:auth_password) }

    trait :space_scoped do
      space_id { create(:space).id }
    end
  end
end
