FactoryBot.define do
  factory :route_binding, class: 'VCAP::CloudController::RouteBinding' do
    service_instance do
      service = create(:service, requires: ['route_forwarding'])
      service_plan = create(:service_plan, service: service)
      create(:managed_service_instance, service_plan: service_plan)
    end
    route             { create(:route, space: service_instance.space) } # rubocop:disable FactoryBot/FactoryAssociationWithStrategy
    route_service_url { generate(:url) }
  end
end
