module VCAP
  module CloudController
    module Diego
      MIN_CPU_PROXY = 128
      MAX_CPU_PROXY = 8192

      class TaskCpuWeightCalculator
        def initialize(memory_in_mb:)
          @memory_in_mb = memory_in_mb
        end

        def calculate
          return 100 if memory_in_mb > MAX_CPU_PROXY
          numerator = [MIN_CPU_PROXY, memory_in_mb].max
          100 * numerator / MAX_CPU_PROXY
        end

        private

        attr_reader :memory_in_mb
      end
    end
  end
end
