module VCAP::CloudController
  class OrganizationInstanceUsageCalculator
    def self.get_instance_usage(org)
      org.processes_dataset.where(state: ProcessModel::STARTED).sum(:instances) || 0
    end
  end
end
