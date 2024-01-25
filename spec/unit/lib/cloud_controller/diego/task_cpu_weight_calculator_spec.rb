require 'spec_helper'
require 'cloud_controller/diego/task_cpu_weight_calculator'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskCpuWeightCalculator do
      describe '#calculate with default values' do
        let(:calculator) { TaskCpuWeightCalculator.new(memory_in_mb: memory) }
        let(:min_cpu_proxy) { VCAP::CloudController::Config.config.get(:cpu_weight_min_memory) }
        let(:max_cpu_proxy) { VCAP::CloudController::Config.config.get(:cpu_weight_max_memory) }

        context 'when the memory limit is below the minimum value' do
          let(:memory) { min_cpu_proxy - 1 }

          it 'returns a percentage of the MIN / MAX' do
            expected_weight = (100 * min_cpu_proxy) / BASE_WEIGHT
            expect(calculator.calculate).to eq(expected_weight)
          end
        end

        context 'when the memory limit is above the maximum default value' do
          let(:memory) { max_cpu_proxy + 1 }

          it 'returns 100' do
            expect(calculator.calculate).to eq(100)
          end
        end

        context 'when the memory limit is between the minimum value and maximum default values' do
          let(:memory) { (min_cpu_proxy + max_cpu_proxy) / 2 }

          it 'returns a percentage that is different' do
            expected_weight = (100 * memory) / BASE_WEIGHT
            expect(calculator.calculate).to eq(expected_weight)
          end
        end
      end

      describe '#calculate with cpu_weight_max_memory=16384' do
        before do
          TestConfig.override(cpu_weight_max_memory: 16_384)
        end

        # let(:calculator) { TaskCpuWeightCalculator.new(memory, TestConfig.config_instance) }
        let(:calculator) { TaskCpuWeightCalculator.new(memory_in_mb: memory) }

        context 'when the memory limit is between the minimum value and maximum default values' do
          let(:memory) { 5000 }

          it 'returns a percentage of 100' do
            expected_weight = (100 * memory) / BASE_WEIGHT
            expect(calculator.calculate).to eq(expected_weight)
          end
        end

        context 'when memory limit is equal to the default maximum (8G)' do
          let(:memory) { BASE_WEIGHT }

          it 'returns 100' do
            expect(calculator.calculate).to eq(100)
          end
        end

        context 'when the memory limit is between the default maximum (8G) and 16G of memory' do
          let(:memory) { 15_000 }

          it 'returns a percentage above 100' do
            expected_weight = (100 * memory) / BASE_WEIGHT
            expect(calculator.calculate).to eq(expected_weight)
          end
        end

        context 'when memory limit is equal to 16G' do
          let(:memory) { BASE_WEIGHT * 2 }

          it 'returns 200' do
            expect(calculator.calculate).to eq(200)
          end
        end

        context 'when memory limit is equal or above 16G' do
          let(:memory) { BASE_WEIGHT * 4 }

          it 'returns 200' do
            expect(calculator.calculate).to eq(200)
          end
        end
      end
    end
  end
end
