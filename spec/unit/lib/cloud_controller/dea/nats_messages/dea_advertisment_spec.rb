require 'spec_helper'
require 'cloud_controller/dea/nats_messages/dea_advertisment'

module VCAP::CloudController
  module Dea::NatsMessages
    describe DeaAdvertisement do
      let(:message) do
        {
            'id' => 'staging-id',
            'url' => 'host:port',
            'stacks' => ['stack-name'],
            'available_memory' => 1024,
            'available_disk' => 756,
            'app_id_to_count' => {
                'app_id' => 2,
                'app_id_2' => 1
            }
        }
      end
      let(:expires) { Time.now.utc.to_i + 10 }

      subject(:ad) { DeaAdvertisement.new(message, expires) }

      describe '#dea_id' do
        its(:dea_id) { should eq 'staging-id' }
      end

      describe '#url' do
        its(:url) { should eq 'host:port' }
      end

      describe '#stats' do
        its(:stats) { should eq message }
      end

      describe '#available_memory' do
        its(:available_memory) { should eq 1024 }
      end

      describe '#available_disk' do
        its(:available_disk) { should eq 756 }
      end

      describe '#expired?' do
        let(:now) { Time.now.utc }
        context 'when the time since the advertisment is greater than or equal 10 seconds' do
          it 'returns true' do
            Timecop.freeze now do
              ad
              Timecop.travel now + 11.seconds do
                expect(ad).to be_expired(Time.now.utc)
              end
            end
          end
        end

        context 'when the time since the advertisment is less than 10 seconds' do
          it 'returns false' do
            Timecop.freeze now do
              ad
              Timecop.travel now + 9.seconds do
                expect(ad).to_not be_expired(Time.now.utc)
              end
            end
          end
        end
      end

      describe '#meets_needs?' do
        context 'when it has the memory' do
          let(:mem) { 512 }

          context 'and it has the stack' do
            let(:stack) { 'stack-name' }
            it { expect(ad.meets_needs?(mem, stack)).to be true }
          end

          context 'and it does not have the stack' do
            let(:stack) { 'not-a-stack-name' }
            it { expect(ad.meets_needs?(mem, stack)).to be false }
          end
        end

        context 'when it does not have the memory' do
          let(:mem) { 2048 }

          context 'and it has the stack' do
            let(:stack) { 'stack-name' }
            it { expect(ad.meets_needs?(mem, stack)).to be false }
          end

          context 'and it does not have the stack' do
            let(:stack) { 'not-a-stack-name' }
            it { expect(ad.meets_needs?(mem, stack)).to be false }
          end
        end
      end

      describe '#has_sufficient_memory?' do
        context 'when the dea does not have enough memory' do
          it 'returns false' do
            expect(ad.has_sufficient_memory?(2048)).to be false
          end
        end

        context 'when the dea has enough memory' do
          it 'returns false' do
            expect(ad.has_sufficient_memory?(512)).to be true
          end
        end
      end

      describe '#has_sufficient_disk?' do
        context 'when the dea does not have enough disk' do
          it 'returns false' do
            expect(ad.has_sufficient_disk?(2048)).to be false
          end
        end

        context 'when the dea does have enough disk' do
          it 'returns false' do
            expect(ad.has_sufficient_disk?(512)).to be true
          end
        end

        context 'when the dea does not report disk space' do
          before { message.delete 'available_disk' }

          it 'always returns true' do
            expect(ad.has_sufficient_disk?(4096 * 10)).to be true
          end
        end
      end

      describe '#has_stack?' do
        context 'when the dea has the stack' do
          it 'returns false' do
            expect(ad.has_stack?('stack-name')).to be true
          end
        end

        context 'when the dea does not have the stack' do
          it 'returns false' do
            expect(ad.has_stack?('not-a-stack-name')).to be false
          end
        end
      end

      describe '#num_instances_of' do
        it { expect(ad.num_instances_of('app_id')).to eq 2 }
        it { expect(ad.num_instances_of('not_on_dea')).to eq 0 }
      end

      describe 'increment_instance_count' do
        it 'increment the instance count' do
          expect {
            ad.increment_instance_count('app_id')
          }.to change {
            ad.num_instances_of('app_id')
          }.from(2).to(3)
        end
      end

      describe 'decrement_memory' do
        it "decrement the dea's memory" do
          expect {
            ad.decrement_memory(512)
          }.to change {
            ad.available_memory
          }.from(1024).to(512)
        end
      end

      describe '#zone' do
        context 'when the dea does not have the placement properties' do
          it 'returns default zone' do
            expect(ad.zone).to eq 'default'
          end
        end

        context 'when the dea has empty placement properties' do
          before { message['placement_properties'] = {} }

          it 'returns default zone' do
            expect(ad.zone).to eq 'default'
          end
        end

        context 'when the dea has the placement properties with zone info' do
          before { message['placement_properties'] = { 'zone' => 'zone_cf' } }

          it 'returns the zone with name zone_cf' do
            expect(ad.zone).to eq 'zone_cf'
          end
        end
      end
    end
  end
end
