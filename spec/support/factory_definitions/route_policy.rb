FactoryBot.define do
  factory :route_policy, class: 'VCAP::CloudController::RoutePolicy' do
    route
    source { "cf:app:#{SecureRandom.uuid}" }
  end
end
