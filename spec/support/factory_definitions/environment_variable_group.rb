FactoryBot.define do
  factory :environment_variable_group, class: 'VCAP::CloudController::EnvironmentVariableGroup' do
    name { "runtime-#{generate(:instance_index)}" }
    environment_json do
      {
        'MOTD' => 'Because of your smile, you make life more beautiful.',
        'COROPRATE_PROXY_SERVER' => 'abc:8080'
      }
    end
  end
end
