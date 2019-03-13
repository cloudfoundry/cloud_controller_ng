require 'models/runtime/security_group'

FactoryBot.define do
  factory :security_group, class: VCAP::CloudController::SecurityGroup do
    name

    rules do
      [
        {
          'protocol' => 'udp',
          'ports' => '8080',
          'destination' => '198.41.191.47/1',
        }
      ]
    end
    staging_default { false }
  end
end
