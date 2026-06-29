FactoryBot.define do
  factory :custom_buildpack, class: 'VCAP::CloudController::CustomBuildpack' do
    url { 'http://acme.com' }

    to_create { |instance| instance }
  end
end
