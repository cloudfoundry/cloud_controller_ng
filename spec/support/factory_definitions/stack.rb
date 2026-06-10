FactoryBot.define do
  factory :stack, class: 'VCAP::CloudController::Stack' do
    name { generate(:stack_name) }
    description { generate(:description) }
  end
end
