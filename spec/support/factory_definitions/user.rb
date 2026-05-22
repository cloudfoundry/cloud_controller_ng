FactoryBot.define do
  factory :user, class: 'VCAP::CloudController::User' do
    guid { Sham.uaa_id }
  end
end
