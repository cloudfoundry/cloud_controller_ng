require 'spec_helper'
require 'cloud_controller/diego/task_cpu_weight_calculator'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskCpuWeightCalculator do
      describe '#calculate' do
        let(:calculator) { TaskCpuWeightCalculator.new(memory_in_mb: memory) }
        let(:min_cpu_proxy) { VCAP::CloudController::Diego::MIN_CPU_PROXY }
        let(:max_cpu_proxy) { VCAP::CloudController::Diego::MAX_CPU_PROXY }

        context 'when the memory limit is below the minimum value' do
          let(:memory) { min_cpu_proxy - 1 }

          it 'returns a percentage of the MIN / MAX' do
            expected_weight = (100 * min_cpu_proxy) / max_cpu_proxy
            expect(calculator.calculate).to eq(expected_weight)
          end
        end

        context 'when the memory limit is above the maximum value' do
          let(:memory) { max_cpu_proxy + 1 }

          it 'returns 100' do
            expect(calculator.calculate).to eq(100)
          end
        end

        context 'when the memory limit is between the minimum and maximum values' do
          let(:memory) { (min_cpu_proxy + max_cpu_proxy) / 2 }

          it 'returns a percentage that is different' do
            expected_weight = (100 * memory) / max_cpu_proxy
            expect(calculator.calculate).to eq(expected_weight)
          end
        end
      end
    end
  end
end
