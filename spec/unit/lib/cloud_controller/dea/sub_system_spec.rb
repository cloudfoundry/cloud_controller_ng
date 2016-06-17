require 'spec_helper'

module VCAP::CloudController
  module Dea
    RSpec.describe SubSystem do
      let(:message_bus) { CfMessageBus::MockMessageBus.new }
      let(:dea_respondent) { instance_double(Respondent, start: nil) }
      let(:hm9000_respondent) { instance_double(HM9000::Respondent, handle_requests: nil) }

      before do
        allow(Client).to receive(:run)
        allow(LegacyBulk).to receive(:register_subscription)
        allow(Respondent).to receive(:new).and_return(dea_respondent)
        allow(HM9000::Respondent).to receive(:new).and_return(hm9000_respondent)
      end

      describe '#self.setup!' do
        it 'starts the correct respondents' do
          expect(Client).to receive(:run)
          expect(LegacyBulk).to receive(:register_subscription)
          expect(dea_respondent).to receive(:start)
          expect(hm9000_respondent).to receive(:handle_requests)

          subject.setup!(message_bus)

          expect(subject.dea_respondent).to eq(dea_respondent)
          expect(subject.hm9000_respondent).to eq(hm9000_respondent)
        end
      end
    end
  end
end
