require 'spec_helper'
require 'messages/organization_quotas_create_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupCreateMessage do
    subject { SecurityGroupCreateMessage.new(params) }

    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to eq ["can't be blank"]
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'meow', name: 'the-name' } }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'name' do
        context 'when it is non-alphanumeric' do
          let(:params) { { name: 'thë-name' } }

          it { is_expected.to be_valid }
        end

        context 'when it contains hyphens' do
          let(:params) { { name: 'a-z' } }

          it { is_expected.to be_valid }
        end

        context 'when it contains capital ascii' do
          let(:params) { { name: 'AZ' } }

          it { is_expected.to be_valid }
        end

        context 'when it is at max length' do
          let(:params) { { name: 'B' * SecurityGroupCreateMessage::MAX_SECURITY_GROUP_NAME_LENGTH } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { name: 'B' * (SecurityGroupCreateMessage::MAX_SECURITY_GROUP_NAME_LENGTH + 1), } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to contain_exactly('is too long (maximum is 250 characters)')
          end
        end

        context 'when it is blank' do
          let(:params) { { name: '' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to include("can't be blank")
          end
        end
      end
      describe 'rules' do
        let(:rules) { [] }

        let(:params) do
          {
            name: 'basic',
            rules: rules,
          }
        end

        context 'when no rules are passed in' do
          let(:params) do
            { name: 'no_rules' }
          end
          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when an empty set of rules is passed in' do
          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when rules is not an array' do
          let(:rules) { 'bad rule' }
          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to include 'Rules must be an array'
          end
        end

        context 'when rules is not an array of hashes' do
          let(:rules) { ['bad rule'] }
          it 'is not valid when rules is not an array of hashes' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to include 'Rules must be an array of hashes'
          end
        end

        describe 'IpProtocolValidator' do

          context 'the protocol is not a string' do
            let(:rules) { [
              { 'protocol': 4 },
            ] }

            it 'adds an error if the field is not a string' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include "Protocol must be 'tcp', 'udp', 'icmp', or 'all'"
            end
          end

          context 'when the protocol field is nil' do
            let(:rules) { [
              { 'protocol': nil }
            ] }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include "Protocol must be 'tcp', 'udp', 'icmp', or 'all'"
            end
          end

          context 'when the protocol field is an unknown type' do
            let(:rules) { [
              { 'protocol': 'arp' }
            ] }
            it 'adds an error' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include "Protocol must be 'tcp', 'udp', 'icmp', or 'all'"
            end
          end

          %w(tcp icmp udp all).each do |proto|
            context "when the protocol field is #{proto}" do
              let(:rules) { [
                { 'protocol': proto,
                  'destination': "10.10.10.0/24",
                  'ports': (proto != "all" ? "8080" : nil),
                  'type': (proto == "icmp" ? -1 : nil),
                  'code': (proto == "icmp" ? 255 : nil)
                }
              ] }

              it "accepts the valid protocol '#{proto}'" do
                expect(subject).to be_valid
                expect(subject.errors[:rules]).to be_empty
              end
            end
          end
        end

        describe 'IcmpValidator' do
          context 'all the icmp rules are valid and the specified protocol is icmp' do
            let(:rules) { [
              { 'protocol': 'icmp',
                'destination': "10.10.10.0/24",
                'type': -1,
                'code': 255
            },
            ] }

            it 'accepts values -1 and higher for type and code' do
              expect(subject).to be_valid
            end

            it 'accepts values 255 and below for type and code' do
              expect(subject).to be_valid
            end
          end

          context 'the icmp rules are not provided when the protocol is icmp' do
            let(:rules) { [
              { 'protocol': 'icmp',
                'destination': "10.10.10.0/24",
              },
            ] }

            it 'is invlaid' do
              expect(subject).to be_invalid
              expect(subject.errors[:type]).to include "is required for protocols of type ICMP"
              expect(subject.errors[:code]).to include "is required for protocols of type ICMP"
            end
          end

          context 'all the icmp rules are out of the valid range' do
            let(:rules) { [
              { 'protocol': 'icmp',
                'type': -2,
                'code': 256
              },
            ] }

            it 'returns a luxurious error for both the upper and lower bounds' do

              expect(subject).to be_invalid
              expect(subject.errors[:type]).to include "must be an integer between -1 and 255 (inclusive)"
              expect(subject.errors[:code]).to include "must be an integer between -1 and 255 (inclusive)"
            end
          end

          context 'all the icmp rules are strings' do
            let(:rules) { [
              { 'protocol': 'icmp',
                'type': "not an int",
                'code': "not an int"
              },
            ] }

            it 'must be an int' do
              expect(subject).to be_invalid
              expect(subject.errors[:type]).to include "must be an integer between -1 and 255 (inclusive)"
              expect(subject.errors[:code]).to include "must be an integer between -1 and 255 (inclusive)"
            end
          end
        end

        describe 'DestinationValidator' do
          context 'the destination is valid' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "10.10.10.0/24",
                'ports': "8080"
              },
            ] }

            it 'accepts the valid destination' do
              expect(subject).to be_valid
            end
          end

          context 'the destination is not a string' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': 42
              },
            ] }

            it 'adds an error if the field is not a string' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Destination must be a string"
            end
          end

          context 'when the destination field is nil' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': nil }
            ] }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Destination must be a valid CIDR, IP address, or IP address range"
            end
          end

          context 'when the destination field contains whitespace' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "10.10.10.10 ",
              }
            ] }
            it 'adds an error' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Destination must not contain whitespace"
            end
          end

          context 'when the destination field is not a valid CIDR or IP range' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "1010",
              }
            ] }
            it 'adds an error' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Destination must be a valid CIDR, IP address, or IP address range"
            end
          end

          context 'when the destination field is an invalid IP range' do
            let(:rules) { [
              { 'protocol': 'tcp',
                'destination': "192.168.10.2-192.168.105",
                'ports': '8080',
              }
            ] }
            it 'adds an error' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Destination must be a valid CIDR, IP address, or IP address range"
            end
          end

          context 'when the destination field is an IP address range in reverse order' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "192.168.10.2-192.168.5.254",
              }
            ] }
            it 'adds an error' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Destination must be a valid CIDR, IP address, or IP address range"
            end
          end

          context 'when the destination field is an invalid CIDR notation' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "192.168.10.2/240",
              }
            ] }
            it 'adds an error' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Destination must be a valid CIDR, IP address, or IP address range"
            end
          end

          context 'when the destination field is a valid IP address' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "192.168.10.2",
                'ports': "8080"
              }
            ] }
            it 'accepts the valid IP address' do
              expect(subject).to be_valid
            end
          end

          context 'when the destination field is a valid IP address range' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "192.168.10.2-192.168.15.254",
                'ports': "8080"
              }
            ] }
            it 'accepts the valid IP address range' do
              expect(subject).to be_valid
            end
          end

          context 'when the destination field is a valid CIDR notation' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "192.168.10.2/24",
                'ports': "8080"
              }
            ] }
            it 'accepts the valid CIDR notation' do
              expect(subject).to be_valid
            end
          end
        end

        describe 'DescriptionValidator' do
          context 'the description is valid' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "192.168.10.2/24",
                'description': 'a description',
                'ports': "8080",
              },
            ] }

            it 'accepts the valid description' do
              expect(subject).to be_valid
            end
          end

          context 'the description is not a string' do
            let(:rules) { [
              { 'protocol': 'udp',
                'description': 42
              },
            ] }

            it 'adds an error if the field is not a string' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Description must be a string"
            end
          end
        end

        describe 'PortsValidator' do
          context 'when the ports are a valid single port' do
            let(:rules) { [
              {
                'protocol': 'udp',
                'destination': "192.168.10.2/24",
                'ports': '8080'
              },
            ] }

            it 'accepts the valid port' do
              expect(subject).to be_valid
            end
          end

          context 'when the ports are a comma separated list' do
            let(:rules) { [
              {
                'protocol': 'udp',
                'destination': "192.168.10.2/24",
                'ports': '3000,8888',
              },
            ] }

            it 'accepts the valid ports list' do
              expect(subject).to be_valid
            end
          end

          context 'when the ports are a valid range' do
            let(:rules) { [
              {
                'protocol': 'udp',
                'destination': "192.168.10.2/24",
                'ports': '4000-5000',
              },
            ] }

            it 'accepts the valid range of ports' do
              expect(subject).to be_valid
            end
          end

          context 'when the ports are not a valid range' do
            let(:rules) { [
              {
                'protocol': 'udp',
                'destination': "192.168.10.2/24",
                'ports': '6000-5000',
              },
            ] }

            it 'does not accept the ports as valid' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Ports must be a valid single port, comma separated list of ports, or range or ports, formatted as a string"
            end
          end

          context 'when the ports are not a string' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "192.168.10.2/24",
                'ports': 42
              },
            ] }

            it 'adds an error if the field is not a string' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Ports must be a valid single port, comma separated list of ports, or range or ports, formatted as a string"
            end
          end

          context 'when the protocol is set to "all"' do
            let(:rules) { [
              {
                'protocol': 'all',
                'destination': "192.168.10.2/24",
                'ports': '6000',
              },
            ] }

            it 'does not accept the provided ports' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Ports are not allowed for protocols of type all"
            end
          end
        end

        describe 'LogValidator' do
          context 'the log is valid' do
            let(:rules) { [
              { 'protocol': 'udp',
                'destination': "192.168.10.2/24",
                'log': true,
                'ports': "8080"
              },
            ] }

            it 'accepts the valid log' do
              expect(subject).to be_valid
            end
          end

          context 'the log is not a boolean' do
            let(:rules) { [
              { 'protocol': 'udp',
                'log': 42,
                'ports': "8080"
              },
            ] }

            it 'adds an error if the field is not a string' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to include \
                "Log must be a boolean"
            end
          end

        end
      end

    end
  end
end

