require 'spec_helper'

module VCAP::CloudController
  RSpec.describe EgressNetworkRulesPresenter do
    let(:sg1) { SecurityGroup.make(rules: [{ 'protocol' => 'udp', 'ports' => '8080', 'destination' => '198.41.191.47/1' }]) }
    let(:sg2) { SecurityGroup.make(rules: [{ 'protocol' => 'tcp', 'ports' => '9090', 'destination' => '198.41.191.48/1', 'log' => true }]) }
    let(:sg3) { SecurityGroup.make(rules: [{ 'protocol' => 'udp', 'ports' => '1010', 'destination' => '198.41.191.49/1' }]) }

    subject { EgressNetworkRulesPresenter.new([sg1, sg2, sg3]) }

    describe '#to_array' do
      it 'returns an aggregated array of rules' do
        expected = [
          { 'protocol' => 'udp', 'ports' => '8080', 'destination' => '198.41.191.47/1' },
          { 'protocol' => 'tcp', 'ports' => '9090', 'destination' => '198.41.191.48/1', 'log' => true },
          { 'protocol' => 'udp', 'ports' => '1010', 'destination' => '198.41.191.49/1' }
        ]
        expect(subject.to_array).to match_array(expected)
      end
    end
  end
end
