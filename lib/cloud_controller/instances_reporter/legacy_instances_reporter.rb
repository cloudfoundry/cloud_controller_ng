module VCAP::CloudController::InstancesReporter
  class LegacyInstancesReporter
    def all_instances_for_app(app)
      VCAP::CloudController::DeaClient.find_all_instances(app)
    end
  end
end