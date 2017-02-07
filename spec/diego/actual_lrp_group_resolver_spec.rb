require 'spec_helper'
require 'diego/actual_lrp_group_resolver'

module Diego
  RSpec.describe ActualLRPGroupResolver do
    describe '.get_lrp' do
      context 'when neither "instance" or "evacuating" is set' do
        let(:actual_lrp_group) { ::Diego::Bbs::Models::ActualLRPGroup.new }

        it 'raises' do
          expect {
            ActualLRPGroupResolver.get_lrp(actual_lrp_group)
          }.to raise_error(ActualLRPGroupResolver::ActualLRPGroupError, 'missing instance and evacuating on actual lrp group')
        end
      end

      context 'when only "instance" is set' do
        let(:actual_lrp_group) { ::Diego::Bbs::Models::ActualLRPGroup.new(instance: actual_lrp) }
        let(:actual_lrp) { ::Diego::Bbs::Models::ActualLRP.new }

        it 'returns the instance lrp' do
          expect(ActualLRPGroupResolver.get_lrp(actual_lrp_group)).to eq(actual_lrp)
        end
      end

      context 'when only "evacuating" is set' do
        let(:actual_lrp_group) { ::Diego::Bbs::Models::ActualLRPGroup.new(evacuating: actual_lrp) }
        let(:actual_lrp) { ::Diego::Bbs::Models::ActualLRP.new }

        it 'returns the evacuating lrp' do
          expect(ActualLRPGroupResolver.get_lrp(actual_lrp_group)).to eq(actual_lrp)
        end
      end

      context 'when both are set' do
        let(:actual_lrp_group) { ::Diego::Bbs::Models::ActualLRPGroup.new(evacuating: evacuating_lrp, instance: instance_lrp) }
        let(:instance_lrp) { ::Diego::Bbs::Models::ActualLRP.new(since: 1) }
        let(:evacuating_lrp) { ::Diego::Bbs::Models::ActualLRP.new(since: 2) }

        it 'defaults to evacuating' do
          expect(ActualLRPGroupResolver.get_lrp(actual_lrp_group)).to eq(evacuating_lrp)
        end

        context 'when the "instance" lrp is in "RUNNING" state' do
          let(:instance_lrp) { ::Diego::Bbs::Models::ActualLRP.new(since: 1, state: ActualLRPState::RUNNING) }

          it 'returns the instance lrp' do
            expect(ActualLRPGroupResolver.get_lrp(actual_lrp_group)).to eq(instance_lrp)
          end
        end

        context 'when the "instance" lrp is in "CRASHING" state' do
          let(:instance_lrp) { ::Diego::Bbs::Models::ActualLRP.new(since: 1, state: ActualLRPState::CRASHED) }

          it 'returns the instance lrp' do
            expect(ActualLRPGroupResolver.get_lrp(actual_lrp_group)).to eq(instance_lrp)
          end
        end
      end
    end
  end
end
