require 'spec_helper'
require 'messages/security_group_apply_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupApplyMessage do
    subject { SecurityGroupApplyMessage.new(params) }

    let(:params) do
      {
        data: [{ guid: 'space-guid-1' }, { guid: 'space-guid-2' }]
      }
    end

    describe '#space_guids' do
      it 'returns the space guids' do
        expect(subject.space_guids).to eq(%w(space-guid-1 space-guid-2))
      end
    end
  end
end
