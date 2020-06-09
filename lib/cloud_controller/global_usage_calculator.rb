module VCAP::CloudController
  class GlobalUsageCalculator
    def self.instance_usage
      ProcessModel.dataset.where(state: ProcessModel::STARTED).sum(:instances) || 0
    end

    def self.memory_usage
      0
    end
  end
end
