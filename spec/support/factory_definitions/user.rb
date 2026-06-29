FactoryBot.define do
  factory :user, class: 'VCAP::CloudController::User' do
    guid { generate(:uaa_id) }
  end
end
