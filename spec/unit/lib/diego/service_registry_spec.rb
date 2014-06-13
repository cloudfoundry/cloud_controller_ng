require 'spec_helper'

module VCAP::CloudController::Diego
  describe ServiceRegistry do

    let(:message_bus) { CfMessageBus::MockMessageBus.new }

    subject { described_class.new(message_bus) }

    before do
      subject.run!
    end

    describe '#tps_addrs' do
      context 'when service.announce.tps messages have been broadcast' do
        before do
          message_bus.publish('service.announce.tps', { addr: 'http://1.2.3.4:456', ttl: 20 })
          message_bus.publish('service.announce.tps', { addr: 'http://1.2.3.5:938', ttl: 180 })
        end

        it 'contains the broadcast ip addresses' do
          expect(subject.tps_addrs).to eq(['http://1.2.3.4:456', 'http://1.2.3.5:938'])
        end

        context 'when a broadcast message has expired' do
          before do
            Timecop.travel(Time.now + 30)
          end

          it 'no longer contains the expired ip address' do
            expect(subject.tps_addrs).to eq(['http://1.2.3.5:938'])
          end
        end
      end
    end
  end
end