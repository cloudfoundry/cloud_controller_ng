# usage: pipe this script into bin/console on the api vm
NUM_ORGS=10
NUM_SPACES=10
NUM_SERVICES=10
NUM_SERVICE_PLANS=5
NUM_SERVICE_INSTANCES=50000
  
NUM_ORGS.times do |i|
  Organization.create(name: "perf-org-#{i}")
end

NUM_SPACES.times do |i|
  Space.create(name: "perf-space#{i}", organization: Organization.all.sample)
end

NUM_SERVICES.times do |i|
  service = Service.create(label: "perf-service#{i}", description: "service #{i}", bindable: [true,false].sample)
  NUM_SERVICE_PLANS.times do |j|
    ServicePlan.create(name: "perf-service-plan-#{i}-#{j}", service: service, description: "service plan #{i}", free: [true, false].sample)
  end
end

NUM_SERVICE_INSTANCES.times do |i|
  ServiceInstance.create(name: "perf-service-instance-#{i}", space: Space.all.sample, is_gateway_service: [true, false].sample, 
                              service_plan_id: ServicePlan.all.sample.id)
end
