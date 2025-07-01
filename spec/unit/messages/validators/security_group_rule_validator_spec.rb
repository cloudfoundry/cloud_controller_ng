require 'spec_helper'
require 'messages/validators/security_group_rule_validator'

module VCAP::CloudController::Validators
  RSpec.describe 'SecurityGroupRuleValidator' do
    let(:class_with_rules) do
      Class.new do
        include ActiveModel::Model
        validates_with RulesValidator

        def self.name
          'TestClass'
        end

        attr_accessor :rules
      end
    end
    let(:rules) { [] }

    subject(:message) { class_with_rules.new(rules:) }

    context 'when an empty set of rules is passed in' do
      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when rules is not an array' do
      let(:rules) { 'bad rule' }

      it 'is not valid' do
        expect(subject).not_to be_valid
        expect(subject.errors[:rules]).to include 'must be an array'
      end
    end

    context 'when more than one rule is invalid' do
      let(:rules) do
        [
          {
            protocol: 'blah'
          },
          {
            'not-a-field': true
          }
        ]
      end

      it 'returns indexed errors corresponding to each invalid rule' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages).to include "Rules[0]: protocol must be 'tcp', 'udp', 'icmp', 'icmpv6' or 'all'"
        expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a valid CIDR, IP address, or IP address range'
        expect(subject.errors.full_messages).to include "Rules[1]: protocol must be 'tcp', 'udp', 'icmp', 'icmpv6' or 'all'"
        expect(subject.errors.full_messages).to include 'Rules[1]: destination must be a valid CIDR, IP address, or IP address range'
      end
    end

    context 'when rules is not an array of hashes' do
      let(:rules) { ['bad rule'] }

      it 'is not valid' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages).to include 'Rules[0]: must be an object'
      end
    end

    context 'when a rule contains an invalid key' do
      let(:rules) do
        [
          {
            blork: 'busted',
            blark: 'also busted'
          }
        ]
      end

      it 'returns an error about the invalid key' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages).to include 'Rules[0]: unknown field(s): ["blork", "blark"]'
      end
    end

    describe 'destination validation' do
      context 'the destination is valid' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '10.10.10.0/24',
              ports: '8080'
            }
          ]
        end

        it 'accepts the valid destination' do
          expect(subject).to be_valid
        end
      end

      context 'the destination is not a string' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: 42
            }
          ]
        end

        it 'adds an error if the field is not a string' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a string'
        end
      end

      context 'when the destination field is nil' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: nil
            }
          ]
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a valid CIDR, IP address, or IP address range'
        end
      end

      context 'when the destination field contains whitespace' do
        context 'in a single destination' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '    10.10.10.10'
              }
            ]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must not contain whitespace'
          end
        end

        context 'in a comma-delimited destination' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '    10.10.10.10   ,   192.168.17.12'
              }
            ]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must not contain whitespace'
          end
        end
      end

      context 'when the destination contains a comma and comma_delimited_destinations are DISABLED' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '10.10.10.10,'
            }
          ]
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a valid CIDR, IP address, or IP address range'
        end
      end

      context 'when there is a leading zero in an octet' do
        context 'in a CIDR' do
          let(:rules) do
            [
              {
                protocol: 'tcp',
                destination: '10.000.0.0/24',
                ports: '443'
              },
              {
                protocol: 'tcp',
                destination: '10.0.0.000/24',
                ports: '443'
              }
            ]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: destination octets cannot contain leading zeros'
            expect(subject.errors.full_messages).to include 'Rules[1]: destination octets cannot contain leading zeros'
          end
        end

        context 'in an IP range' do
          let(:rules) do
            [
              {
                protocol: 'tcp',
                destination: '1.0.0.000-1.0.0.200',
                ports: '443'
              }
            ]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: destination octets cannot contain leading zeros'
          end
        end

        context 'in an IP' do
          let(:rules) do
            [
              {
                protocol: 'tcp',
                destination: '010.0.0.53',
                ports: '443'
              },
              {
                protocol: 'tcp',
                destination: '10.000.0.53',
                ports: '443'
              },
              {
                protocol: 'tcp',
                destination: '10.0.000.53',
                ports: '443'
              },
              {
                protocol: 'tcp',
                destination: '10.0.0.053',
                ports: '443'
              },
              {
                protocol: 'tcp',
                destination: '010.000.000.053',
                ports: '443'
              }
            ]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages.length).to eq(5)
            expect(subject.errors.full_messages).to include 'Rules[0]: destination octets cannot contain leading zeros'
            expect(subject.errors.full_messages).to include 'Rules[1]: destination octets cannot contain leading zeros'
            expect(subject.errors.full_messages).to include 'Rules[2]: destination octets cannot contain leading zeros'
            expect(subject.errors.full_messages).to include 'Rules[3]: destination octets cannot contain leading zeros'
            expect(subject.errors.full_messages).to include 'Rules[4]: destination octets cannot contain leading zeros'
          end
        end
      end

      context 'when the destination field is not a valid CIDR or IP range' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '1010'
            }
          ]
        end

        it 'adds an error' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a valid CIDR, IP address, or IP address range'
        end
      end

      context 'when the destination field is an invalid IP range' do
        let(:rules) do
          [
            {
              protocol: 'tcp',
              destination: '192.168.10.2-192.168.105',
              ports: '8080'
            }
          ]
        end

        it 'adds an error' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: destination IP address range is invalid'
        end
      end

      context 'when the destination field is an IP address range in reverse order' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '9.9.9.9-0.0.0.0'
            }
          ]
        end

        it 'adds an error' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: beginning of IP address range is numerically greater than the end of its range (range endpoints are inverted)'
        end
      end

      context 'when the destination field is an invalid CIDR notation' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/240'
            }
          ]
        end

        it 'adds an error' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a valid CIDR, IP address, or IP address range'
        end
      end

      context 'when the destination field is a valid IP address' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2',
              ports: '8080'
            }
          ]
        end

        it 'accepts the valid IP address' do
          expect(subject).to be_valid
        end
      end

      context 'when the destination field is a valid IP address range' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2-192.168.15.254',
              ports: '8080'
            }
          ]
        end

        it 'accepts the valid IP address range' do
          expect(subject).to be_valid
        end
      end

      context 'when the destination field is a valid CIDR notation' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/24',
              ports: '8080'
            }
          ]
        end

        it 'accepts the valid CIDR notation' do
          expect(subject).to be_valid
        end
      end

      context 'comma-delimited destinations are enabled' do
        before do
          TestConfig.config[:security_groups][:enable_comma_delimited_destinations] = true
        end

        context 'the destination is valid comma-delimited list' do
          context 'of CIDRs' do
            let(:rules) do
              [
                {
                  protocol: 'udp',
                  destination: '10.0.0.0/8,192.168.0.0/16',
                  ports: '8080'
                }
              ]
            end

            it 'accepts the destination' do
              expect(subject).to be_valid
            end
          end

          context 'of a CIDR, a range and an IP address' do
            let(:rules) do
              [
                {
                  protocol: 'udp',
                  destination: '10.0.0.0/8,1.0.0.0-1.0.0.255,4.5.6.7',
                  ports: '8080'
                }
              ]
            end

            it 'accepts the chimeric destination' do
              expect(subject).to be_valid
            end
          end
        end

        context 'the destination is nil' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: nil,
                ports: '8080'
              }
            ]
          end

          it 'throws a specific error including mention of comma-delimited destinations' do
            expected_error = 'Rules[0]: nil destination; destination must be a comma-delimited list of valid CIDRs, IP addresses, or IP address ranges'

            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include expected_error
          end
        end

        context 'one of the destinations is invalid' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '192.168.10.2/24,1.2',
                ports: '8080'
              }
            ]
          end

          it 'throws a specific error to comma-delimited destinations' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
          end
        end

        context 'all of the destinations are invalid' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '1.2-7.8,999.999.999.999,200.0.0.0-150.0.0.0,10.0.0.0/500',
                ports: '8080'
              }
            ]
          end

          it 'throws an error for every destination' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages.length).to equal(4)
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
            expect(subject.errors.full_messages).to include 'Rules[0]: destination IP address range is invalid'

            expected_error = 'Rules[0]: beginning of IP address range is numerically greater than the end of its range (range endpoints are inverted)'
            expect(subject.errors.full_messages).to include expected_error
          end
        end

        context 'more than 6000 destinations per rule' do
          let(:rules) do
            [
              {
                protocol: 'all',
                destination: (['192.168.1.3'] * 7000).join(',')
              }
            ]
          end

          it 'throws an error' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: maximum destinations per rule exceeded - must be under 6000'
          end
        end

        context 'empty destinations in the front are invalid' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: ',10.10.10.10,11.11.11.11',
                ports: '8080'
              }
            ]
          end

          it 'throws an error for the missing destination' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages.length).to equal(2)
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
            expect(subject.errors.full_messages).to include 'Rules[0]: empty destination specified in comma-delimited list'
          end
        end

        context 'empty destinations in the middle are invalid' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '10.10.10.10,,11.11.11.11',
                ports: '8080'
              }
            ]
          end

          it 'throws an error for the missing destination' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages.length).to equal(2)
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
            expect(subject.errors.full_messages).to include 'Rules[0]: empty destination specified in comma-delimited list'
          end
        end

        context 'empty destinations at the end are invalid' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '10.10.10.10,11.11.11.11,',
                ports: '8080'
              }
            ]
          end

          it 'throws an error for the missing destination' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages.length).to equal(2)
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
            expect(subject.errors.full_messages).to include 'Rules[0]: empty destination specified in comma-delimited list'
          end
        end

        context 'multiple empty destinations are invalid' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: ',10.10.10.10,,11.11.11.11,',
                ports: '8080'
              }
            ]
          end

          it 'throws an error for each missing destination' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages.length).to equal(6)
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
            expect(subject.errors.full_messages[0]).to eq 'Rules[0]: empty destination specified in comma-delimited list'
            expect(subject.errors.full_messages[2]).to eq 'Rules[0]: empty destination specified in comma-delimited list'
            expect(subject.errors.full_messages[4]).to eq 'Rules[0]: empty destination specified in comma-delimited list'
          end
        end
      end

      describe 'ipv6' do
        before do
          TestConfig.config[:enable_ipv6] = true
        end

        context 'the destination is valid ipv6' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '2001:db8::/32',
                ports: '8080'
              }
            ]
          end

          it 'accepts the valid destination' do
            expect(subject).to be_valid
          end
        end

        context 'the destination is valid ipv4' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '10.10.10.0/24',
                ports: '8080'
              }
            ]
          end

          it 'accepts the valid destination' do
            expect(subject).to be_valid
          end
        end

        context 'when the destination field contains whitespace' do
          context 'in a single destination' do
            let(:rules) do
              [
                {
                  protocol: 'udp',
                  destination: '    2001:0db8::1'
                }
              ]
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors.full_messages).to include 'Rules[0]: destination must not contain whitespace'
            end
          end

          context 'in a comma-delimited destination' do
            let(:rules) do
              [
                {
                  protocol: 'udp',
                  destination: '    2001:0db8::1   ,   2001:0db8::2'
                }
              ]
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors.full_messages).to include 'Rules[0]: destination must not contain whitespace'
            end
          end
        end

        context 'when the destination contains a comma and comma_delimited_destinations are DISABLED' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '2001:0db8::1,'
              }
            ]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a valid CIDR, IP address, or IP address range'
          end
        end

        context 'when there is a leading zero in a segment' do
          context 'in a CIDR' do
            let(:rules) do
              [
                {
                  protocol: 'tcp',
                  destination: '2001:0db8::/32',
                  ports: '443'
                },
                {
                  protocol: 'tcp',
                  destination: '2001:db8:0000::/32',
                  ports: '443'
                }
              ]
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'in an IP range' do
            let(:rules) do
              [
                {
                  protocol: 'tcp',
                  destination: '2001:0db8::1-2001:0db8::ff',
                  ports: '443'
                }
              ]
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'in an IP' do
            let(:rules) do
              [
                {
                  protocol: 'tcp',
                  destination: '2001:0db8::1',
                  ports: '443'
                },
                {
                  protocol: 'tcp',
                  destination: '2001:db8:0000::1',
                  ports: '443'
                },
                {
                  protocol: 'tcp',
                  destination: '2001:db8::0001',
                  ports: '443'
                },
                {
                  protocol: 'tcp',
                  destination: '2001:db8::01',
                  ports: '443'
                },
                {
                  protocol: 'tcp',
                  destination: '2001:db8:0000:0000::01',
                  ports: '443'
                }
              ]
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end
        end

        context 'when the destination field is an invalid IP range' do
          let(:rules) do
            [
              {
                protocol: 'tcp',
                destination: '2001:db8::1-2001:db8::g',
                ports: '8080'
              }
            ]
          end

          it 'adds an error' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: destination IP address range is invalid'
          end
        end

        context 'when the destination field is an IP address range in reverse order' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '2001:db8::ff-2001:db8::1'
              }
            ]
          end

          it 'adds an error' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).
              to include 'Rules[0]: beginning of IP address range is numerically greater than the end of its range (range endpoints are inverted)'
          end
        end

        context 'when the destination field is an invalid CIDR notation' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '2001:db8::/129'
              }
            ]
          end

          it 'adds an error' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a valid CIDR, IP address, or IP address range'
          end
        end

        context 'when the destination field is a valid IP address' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '2001:db8::',
                ports: '8080'
              }
            ]
          end

          it 'accepts the valid IP address' do
            expect(subject).to be_valid
          end
        end

        context 'when the destination field is a valid IP address range' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '2001:db8::1-2001:db8::ff',
                ports: '8080'
              }
            ]
          end

          it 'accepts the valid IP address range' do
            expect(subject).to be_valid
          end
        end

        context 'when the destination field is a valid CIDR notation' do
          let(:rules) do
            [
              {
                protocol: 'udp',
                destination: '2001:db8::/32',
                ports: '8080'
              }
            ]
          end

          it 'accepts the valid CIDR notation' do
            expect(subject).to be_valid
          end
        end

        context 'comma-delimited destinations are enabled' do
          before do
            TestConfig.config[:security_groups][:enable_comma_delimited_destinations] = true
          end

          context 'the destination is valid comma-delimited list' do
            context 'of CIDRs' do
              let(:rules) do
                [
                  {
                    protocol: 'udp',
                    destination: '2001:db8::/32,2001:db8:85a3::/64',
                    ports: '8080'
                  }
                ]
              end

              it 'accepts the destination' do
                expect(subject).to be_valid
              end
            end

            context 'of a CIDR, a range and an IP address' do
              let(:rules) do
                [
                  {
                    protocol: 'udp',
                    destination: '2001:db8::/32,2001:db8::1-2001:db8::ff,2001:db8::2',
                    ports: '8080'
                  }
                ]
              end

              it 'accepts the chimeric destination' do
                expect(subject).to be_valid
              end
            end

            context 'of a IPv4 and IPv6 address' do
              let(:rules) do
                [
                  {
                    protocol: 'udp',
                    destination: '2001:db8::,4.5.6.7',
                    ports: '8080'
                  }
                ]
              end

              it 'accepts the chimeric destination' do
                expect(subject).to be_valid
              end
            end
          end

          context 'one of the destinations is invalid' do
            let(:rules) do
              [
                {
                  protocol: 'udp',
                  destination: '2001:db8::/32,2001',
                  ports: '8080'
                }
              ]
            end

            it 'throws a specific error to comma-delimited destinations' do
              expect(subject).not_to be_valid
              expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
            end
          end

          context 'all of the destinations are invalid' do
            let(:rules) do
              [
                {
                  protocol: 'udp',
                  destination: '2001:db8::1-2001:db8::g,2001:db8::/129,2001:db8::ff-2001:db8::1',
                  ports: '8080'
                }
              ]
            end

            it 'throws an error for every destination' do
              expect(subject).not_to be_valid
              expect(subject.errors.full_messages.length).to equal(3)
              expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
              expect(subject.errors.full_messages).to include 'Rules[0]: destination IP address range is invalid'

              expected_error = 'Rules[0]: beginning of IP address range is numerically greater than the end of its range (range endpoints are inverted)'
              expect(subject.errors.full_messages).to include expected_error
            end
          end

          context 'more than 6000 destinations per rule' do
            let(:rules) do
              [
                {
                  protocol: 'all',
                  destination: (['2001:db8::'] * 7000).join(',')
                }
              ]
            end

            it 'throws an error' do
              expect(subject).not_to be_valid
              expect(subject.errors.full_messages).to include 'Rules[0]: maximum destinations per rule exceeded - must be under 6000'
            end
          end

          context 'ipv6 is disabled' do
            before do
              TestConfig.config[:enable_ipv6] = false
            end

            context 'when the destination contains IPv4 and IPv6 addresses' do
              let(:rules) do
                [
                  {
                    protocol: 'udp',
                    destination: '2001:db8::,192.168.200.1',
                    ports: '8080'
                  }
                ]
              end

              it 'throws an error' do
                expect(subject).not_to be_valid
                expect(subject.errors.full_messages).to include 'Rules[0]: destination must contain valid CIDR(s), IP address(es), or IP address range(s)'
              end
            end
          end
        end

        context 'ipv6 is disabled' do
          before do
            TestConfig.config[:enable_ipv6] = false
          end

          context 'when the destination field is a valid IPv6 address' do
            let(:rules) do
              [
                {
                  protocol: 'udp',
                  destination: '2001:db8::',
                  ports: '8080'
                }
              ]
            end

            it 'does not accept a valid ipv6 address' do
              expect(subject).not_to be_valid
              expect(subject.errors.full_messages).to include 'Rules[0]: destination must be a valid CIDR, IP address, or IP address range'
            end
          end
        end
      end
    end

    describe 'description validation' do
      context 'the description is valid' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/24',
              description: 'a description',
              ports: '8080'
            }
          ]
        end

        it 'accepts the valid description' do
          expect(subject).to be_valid
        end
      end

      context 'the description is not a string' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              description: 42
            }
          ]
        end

        it 'adds an error if the field is not a string' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: description must be a string'
        end
      end
    end

    describe 'log validation' do
      context 'the log is valid' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/24',
              log: true,
              ports: '8080'
            }
          ]
        end

        it 'accepts the valid log' do
          expect(subject).to be_valid
        end
      end

      context 'the log is not a boolean' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              log: 42,
              ports: '8080'
            }
          ]
        end

        it 'adds an error if the field is not a string' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include('Rules[0]: log must be a boolean')
        end
      end
    end

    describe 'protocol validation' do
      context 'the protocol is not a string' do
        let(:rules) { [{ protocol: 4 }] }

        it 'adds an error' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include "Rules[0]: protocol must be 'tcp', 'udp', 'icmp', 'icmpv6' or 'all'"
        end
      end

      context 'when the protocol field is nil' do
        let(:rules) { [{ protocol: nil }] }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include "Rules[0]: protocol must be 'tcp', 'udp', 'icmp', 'icmpv6' or 'all'"
        end
      end

      context 'when the protocol field is an unknown type' do
        let(:rules) { [{ protocol: 'arp' }] }

        it 'adds an error' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include "Rules[0]: protocol must be 'tcp', 'udp', 'icmp', 'icmpv6' or 'all'"
        end
      end

      %w[tcp icmp udp all].each do |proto|
        context "when the protocol field is #{proto}" do
          let(:rules) do
            [
              {
                protocol: proto,
                destination: '10.10.10.0/24',
                ports: (proto == 'all' ? nil : '8080'),
                type: (proto == 'icmp' ? -1 : nil),
                code: (proto == 'icmp' ? 255 : nil)
              }
            ]
          end

          it "accepts the valid protocol '#{proto}'" do
            expect(subject).to be_valid
            expect(subject.errors.full_messages).to be_empty
          end
        end
      end
    end

    describe 'port validation' do
      context 'when the ports are a valid single port' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/24',
              ports: '8080'
            }
          ]
        end

        it 'accepts the valid port' do
          expect(subject).to be_valid
        end
      end

      context 'when the ports are a comma separated list' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/24',
              ports: '3000,8888'
            }
          ]
        end

        it 'accepts the valid ports list' do
          expect(subject).to be_valid
        end
      end

      context 'when the ports are a valid range' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/24',
              ports: '4000-5000'
            }
          ]
        end

        it 'accepts the valid range of ports' do
          expect(subject).to be_valid
        end
      end

      context 'when the ports are not provided and protocol is tcp or udp' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/24'
            }
          ]
        end

        it 'accepts the valid port' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include(
            'Rules[0]: ports are required for protocols of type TCP and UDP'
          )
        end
      end

      context 'when the ports are not a valid range' do
        let(:rules) do
          [
            {
              protocol: 'udp',
              destination: '192.168.10.2/24',
              ports: '6000-5000'
            }
          ]
        end

        it 'does not accept the ports as valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include(
            'Rules[0]: ports must be a valid single port, comma separated list of ports, or range or ports, formatted as a string'
          )
        end
      end

      context 'when the ports are not a string' do
        let(:rules) do
          [
            { protocol: 'udp',
              destination: '192.168.10.2/24',
              ports: 42 }
          ]
        end

        it 'adds an error if the field is not a string' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include(
            'Rules[0]: ports must be a valid single port, comma separated list of ports, or range or ports, formatted as a string'
          )
        end
      end

      context 'when the protocol is set to "all"' do
        let(:rules) do
          [
            {
              protocol: 'all',
              destination: '192.168.10.2/24',
              ports: '6000'
            }
          ]
        end

        it 'does not accept the provided ports' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include('Rules[0]: ports are not allowed for protocols of type all')
        end
      end
    end

    describe 'ICMP validation' do
      context 'all the icmp rules are valid and the specified protocol is icmp' do
        let(:rules) do
          [
            {
              protocol: 'icmp',
              destination: '10.10.10.0/24',
              type: -1,
              code: 255
            }
          ]
        end

        it 'accepts values -1 and higher for type and code' do
          expect(subject).to be_valid
        end

        it 'accepts values 255 and below for type and code' do
          expect(subject).to be_valid
        end
      end

      context 'the icmp rules are not provided when the protocol is icmp' do
        let(:rules) do
          [
            {
              protocol: 'icmp',
              destination: '10.10.10.0/24'
            }
          ]
        end

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: type is required for protocols of type ICMP'
          expect(subject.errors.full_messages).to include 'Rules[0]: code is required for protocols of type ICMP'
        end
      end

      context 'all the icmp rules are out of the valid range' do
        let(:rules) do
          [
            {
              protocol: 'icmp',
              type: -2,
              code: 256
            }
          ]
        end

        it 'returns a luxurious error for both the upper and lower bounds' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: type must be an integer between -1 and 255 (inclusive)'
          expect(subject.errors.full_messages).to include 'Rules[0]: code must be an integer between -1 and 255 (inclusive)'
        end
      end

      context 'all the icmp rules are strings' do
        let(:rules) do
          [
            {
              protocol: 'icmp',
              type: 'not an int',
              code: 'not an int'
            }
          ]
        end

        it 'must be an int' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages).to include 'Rules[0]: type must be an integer between -1 and 255 (inclusive)'
          expect(subject.errors.full_messages).to include 'Rules[0]: code must be an integer between -1 and 255 (inclusive)'
        end
      end

      context 'ipv6 is disabled' do
        before do
          TestConfig.config[:enable_ipv6] = false
        end

        context 'icmpv6 protocol in a rule' do
          let(:rules) do
            [
              {
                protocol: 'icmpv6',
                destination: '2001:db8::/32',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: icmpv6 cannot be used if enable_ipv6 is false'
          end
        end
      end

      context 'ipv6 is enabled' do
        before do
          TestConfig.config[:enable_ipv6] = true
        end

        context 'icmp protocol contains an IPv6 destination' do
          let(:rules) do
            [
              {
                protocol: 'icmp',
                destination: '2001:db8::/32',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: for protocol "icmp" you cannot use IPv6 addresses'
          end
        end

        context 'icmp protocol contains an IPv6 destination range' do
          let(:rules) do
            [
              {
                protocol: 'icmp',
                destination: '2001:0db8::1-2001:0db8::ff',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: for protocol "icmp" you cannot use IPv6 addresses'
          end
        end

        context 'icmp protocol contains a comma-delimited list of IPv6 destinations' do
          before do
            TestConfig.config[:security_groups][:enable_comma_delimited_destinations] = true
          end

          let(:rules) do
            [
              {
                protocol: 'icmp',
                destination: '2001:db8::/32,2001:db8:85a3::/64',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: for protocol "icmp" you cannot use IPv6 addresses'
          end
        end

        context 'icmpv6 protocol contains an IPv6 destination' do
          let(:rules) do
            [
              {
                protocol: 'icmpv6',
                destination: '2001:db8::/32',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'icmpv6 protocol contains a comma-delimited list of IPv6 destinations' do
          before do
            TestConfig.config[:security_groups][:enable_comma_delimited_destinations] = true
          end

          let(:rules) do
            [
              {
                protocol: 'icmpv6',
                destination: '2001:db8::/32,2001:db8:85a3::/64',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'icmpv6 protocol contains an IPv4 destination' do
          let(:rules) do
            [
              {
                protocol: 'icmpv6',
                destination: '10.0.0.0/8',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: for protocol "icmpv6" you cannot use IPv4 addresses'
          end
        end

        context 'icmpv6 protocol contains an IPv4 destination range' do
          let(:rules) do
            [
              {
                protocol: 'icmpv6',
                destination: '1.0.0.000-1.0.0.200',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: for protocol "icmpv6" you cannot use IPv4 addresses'
          end
        end

        context 'icmpv6 protocol contains a comma-delimited list of IPv4/IPv6 destinations' do
          before do
            TestConfig.config[:security_groups][:enable_comma_delimited_destinations] = true
          end

          let(:rules) do
            [
              {
                protocol: 'icmpv6',
                destination: '10.0.0.0/8,2001:db8::/32',
                type: -1,
                code: 255
              }
            ]
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: for protocol "icmpv6" you cannot use IPv4 addresses'
          end
        end

        context 'the icmp rules are not provided when the protocol is icmpv6' do
          let(:rules) do
            [
              {
                protocol: 'icmpv6',
                destination: '2001:db8::/32'
              }
            ]
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject.errors.full_messages).to include 'Rules[0]: type is required for protocols of type ICMP'
            expect(subject.errors.full_messages).to include 'Rules[0]: code is required for protocols of type ICMP'
          end
        end
      end
    end
  end
end
