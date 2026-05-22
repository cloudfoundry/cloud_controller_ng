FactoryBot.define do
  factory :domain, class: 'VCAP::CloudController::Domain' do
    name { generate(:domain) }
  end
end
