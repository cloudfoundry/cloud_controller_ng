require 'spec_helper'
require 'cloud_controller/dea/nats_messages/stager_advertisment'

module VCAP::CloudController
  module Dea::NatsMessages
    describe StagerAdvertisement do
      let(:message) do
        {
            'id' => 'staging-id',
            'stacks' => ['stack-name'],
            'available_memory' => 1024,
        }
      end
      let(:expires) { Time.now.utc.to_i + 10 }

      subject(:ad) { StagerAdvertisement.new(message, expires) }

      describe '#stager_id' do
        its(:stager_id) { should eq 'staging-id' }
      end

      describe '#stats' do
        its(:stats) { should eq message }
      end

      describe '#available_memory' do
        its(:available_memory) { should eq 1024 }
      end

      describe '#expired?' do
        let(:now) { Time.now.utc }
        context 'when the time since the advertisment is greater than or equal to 10 seconds' do
          it 'returns true' do
            Timecop.freeze now do
              ad
              Timecop.freeze now + 10.seconds do
                expect(ad).to be_expired(Time.now.utc)
              end
            end
          end
        end

        context 'when the time since the advertisment is less than 10 seconds' do
          it 'returns false' do
            Timecop.freeze now do
              ad
              Timecop.freeze now + 9.seconds do
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
        context 'when the stager does not have enough memory' do
          it 'returns false' do
            expect(ad.has_sufficient_memory?(2048)).to be false
          end
        end

        context 'when the stager has enough memory' do
          it 'returns false' do
            expect(ad.has_sufficient_memory?(512)).to be true
          end
        end
      end

      describe '#has_stack?' do
        context 'when the stager has the stack' do
          it 'returns false' do
            expect(ad.has_stack?('stack-name')).to be true
          end
        end

        context 'when the stager does not have the stack' do
          it 'returns false' do
            expect(ad.has_stack?('not-a-stack-name')).to be false
          end
        end
      end

      describe 'decrement_memory' do
        it "decrement the stager's memory" do
          expect {
            ad.decrement_memory(512)
          }.to change {
            ad.available_memory
          }.from(1024).to(512)
        end
      end
    end
  end
end
