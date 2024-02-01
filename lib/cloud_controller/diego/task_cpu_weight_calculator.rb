module VCAP
  module CloudController
    module Diego
      # Base 100% weight equals an 8G instance
      BASE_WEIGHT = 8192
      class TaskCpuWeightCalculator
        def initialize(memory_in_mb:)
          @memory_in_mb = memory_in_mb
          @min_cpu_proxy = VCAP::CloudController::Config.config.get(:cpu_weight_min_memory)
          @max_cpu_proxy = VCAP::CloudController::Config.config.get(:cpu_weight_max_memory)
        end

        def calculate
          # CPU weight scales linearly with memory between the configured min/max values and base 100% weight
          numerator = [min_cpu_proxy, memory_in_mb].max
          numerator = [max_cpu_proxy, numerator].min

          100 * numerator / BASE_WEIGHT
        end

        private

        attr_reader :memory_in_mb, :min_cpu_proxy, :max_cpu_proxy
      end
    end
  end
end
