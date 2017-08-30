require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe EgressRules do
      subject(:egress_rules) { described_class.new }

      describe '#staging' do
        let(:space) { VCAP::CloudController::Space.make }
        let(:process) { VCAP::CloudController::ProcessModelFactory.make(space: space) }

        before do
          SecurityGroup.make(guid: 'guid1', rules: [{ 'protocol' => 'udp', 'ports' => '8080-9090', 'destination' => '198.41.191.47/1' }], staging_default: true)
          SecurityGroup.make(guid: 'guid2', rules: [{ 'protocol' => 'tcp', 'ports' => '8080,9090', 'destination' => '198.41.191.48/1', 'log' => true }], staging_default: true)
          SecurityGroup.make(guid: 'guid3', rules: [{ 'protocol' => 'tcp', 'ports' => '443', 'destination' => '198.41.191.49/1' }], staging_default: true)
          SecurityGroup.make(guid: 'guid4', rules: [{ 'protocol' => 'icmp', 'destination' => '1.1.1.1-2.2.2.2', 'type' => 0, 'code' => 1 }], staging_default: true)
          SecurityGroup.make(guid: 'guid5', rules: [{ 'protocol' => 'tcp', 'ports' => '80', 'destination' => '0.0.0.0/0' }], staging_default: false)
        end

        it 'includes egress information for default staging security groups' do
          expect(egress_rules.staging(app_guid: process.app.guid)).to match_array([
            { 'protocol' => 'udp', 'port_range' => { 'start' => 8080, 'end' => 9090 }, 'destinations' => ['198.41.191.47/1'], 'annotations' => ['security_group_id:guid1'] },
            { 'protocol' => 'tcp', 'ports' => [8080, 9090], 'destinations' => ['198.41.191.48/1'], 'log' => true, 'annotations' => ['security_group_id:guid2'] },
            { 'protocol' => 'tcp', 'ports' => [443], 'destinations' => ['198.41.191.49/1'], 'annotations' => ['security_group_id:guid3'] },
            { 'protocol' => 'icmp', 'icmp_info' => { 'type' => 0, 'code' => 1 }, 'destinations' => ['1.1.1.1-2.2.2.2'], 'annotations' => ['security_group_id:guid4'] },
          ])
        end

        it 'orders the rules with logged rules last' do
          logged = egress_rules.staging(app_guid: process.app.guid).drop_while { |rule| !rule['log'] }
          expect(logged).to have(1).items
        end

        context 'when the app space has staging security groups' do
          before do
            security_group = SecurityGroup.make(guid: 'guid6', rules: [{ 'protocol' => 'udp', 'ports' => '8081-9090', 'destination' => '198.41.191.50/1' }], staging_default: false)
            security_group.add_staging_space(space)
          end

          it 'includes security groups associated with the space for staging' do
            expect(egress_rules.staging(app_guid: process.app.guid)).to include(
              { 'protocol' => 'udp', 'port_range' => { 'start' => 8081, 'end' => 9090 }, 'destinations' => ['198.41.191.50/1'], 'annotations' => ['security_group_id:guid6'] },
            )
          end
        end

        context 'when the app space has staging security groups with the same rule as default staging' do
          before do
            security_group = SecurityGroup.make(guid: 'guid6', rules: [{ 'protocol' => 'udp', 'ports' => '8080-9090', 'destination' => '198.41.191.47/1' }], staging_default: false)
            security_group.add_staging_space(space)
          end

          it 'creates annotations with the guids for the default security group and the space security group' do
            expect(egress_rules.staging(app_guid: process.app.guid)).to include(
              { 'protocol' => 'udp', 'port_range' => { 'start' => 8080, 'end' => 9090 }, 'destinations' => ['198.41.191.47/1'],
                'annotations' => ['security_group_id:guid1', 'security_group_id:guid6'] },
            )
          end
        end
      end

      describe '#running' do
        let(:process) { ProcessModelFactory.make }
        let(:sg_default_rules_1) { [{ 'protocol' => 'udp', 'ports' => '8080', 'destination' => '198.41.191.47/1' }] }
        let(:sg_default_rules_2) { [{ 'protocol' => 'tcp', 'ports' => '9090-9095', 'destination' => '198.41.191.48/1', 'log' => true }] }
        let(:sg_for_space_rules) { [{ 'protocol' => 'udp', 'ports' => '1010,2020', 'destination' => '198.41.191.49/1' }] }

        before do
          SecurityGroup.make(guid: 'guid1', rules: sg_default_rules_1, running_default: true)
          SecurityGroup.make(guid: 'guid2', rules: sg_default_rules_2, running_default: true)
          process.space.add_security_group(SecurityGroup.make(guid: 'guid3', rules: sg_for_space_rules))
        end

        it 'should provide the egress rules in the start message' do
          expect(egress_rules.running(process)).to match_array([
            { 'protocol' => 'udp', 'ports' => [8080], 'destinations' => ['198.41.191.47/1'],
              'annotations' => ['security_group_id:guid1'] },
            { 'protocol' => 'tcp', 'port_range' => { 'start' => 9090, 'end' => 9095 }, 'destinations' => ['198.41.191.48/1'], 'log' => true,
              'annotations' => ['security_group_id:guid2'] },
            { 'protocol' => 'udp', 'ports' => [1010, 2020], 'destinations' => ['198.41.191.49/1'],
              'annotations' => ['security_group_id:guid3'] },
          ])
        end

        it 'orders the rules with logged rules last' do
          logged = egress_rules.running(process).drop_while { |rule| !rule['log'] }
          expect(logged).to have(1).items
        end

        context 'when the app space has running security groups with the same rule as default running' do
          before do
            security_group = SecurityGroup.make(guid: 'guid4', rules: sg_default_rules_1, running_default: false)
            process.space.add_security_group(security_group)
          end

          it 'creates annotations with the guids for the default security group and the space security group' do
            expect(egress_rules.running(process)).to include(
              { 'protocol' => 'udp', 'ports' => [8080], 'destinations' => ['198.41.191.47/1'], 'annotations' => ['security_group_id:guid1', 'security_group_id:guid4'] },
            )
          end
        end
      end
    end
  end
end
