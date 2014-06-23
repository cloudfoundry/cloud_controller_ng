require 'spec_helper'

module VCAP::CloudController
  describe EgressNetworkRulesPresenter do

    let(:asg1) { AppSecurityGroup.make(rules: [{"protocol" => "udp", "ports" => "8080", "destination" => "198.41.191.47/1"}]) }
    let(:asg2) { AppSecurityGroup.make(rules: [{"protocol" => "tcp", "ports" => "9090", "destination" => "198.41.191.48/1"}]) }
    let(:asg3) { AppSecurityGroup.make(rules: [{"protocol" => "udp", "ports" => "1010", "destination" => "198.41.191.49/1"}]) }

    subject { described_class.new([asg1, asg2, asg3]) }

    describe '#to_array' do
      it 'returns an aggregated array of rules' do
        expect(subject.to_array).to match_array([
          { "protocol" => "udp", "ports" => "8080", "destination" => "198.41.191.47/1" },
          { "protocol" => "tcp", "ports" => "9090", "destination" => "198.41.191.48/1" },
          { "protocol" => "udp", "ports" => "1010", "destination" => "198.41.191.49/1" }
        ])
      end
    end
  end
end
