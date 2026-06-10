FactoryBot.define do
  factory :security_group, class: 'VCAP::CloudController::SecurityGroup' do
    name { generate(:name) }
    rules do
      [
        {
          'protocol' => 'udp',
          'ports' => '8080',
          'destination' => '198.41.191.47/1'
        }
      ]
    end
    running_default { false }
    staging_default { false }
  end
end
