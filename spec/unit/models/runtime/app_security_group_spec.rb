# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe AppSecurityGroup, type: :model do
    def build_transport_rule(attrs={})
      {
        'protocol'    => 'udp',
        'ports'        => '8080-9090',
        'destination' => '198.41.191.47/1'
      }.merge(attrs)
    end

    def build_icmp_rule(attrs={})
      {
        'protocol' => 'icmp',
        'type' => 0,
        'code' => 0,
        'destination' => '0.0.0.0/0'
      }.merge(attrs)
    end

    shared_examples 'a transport rule' do
      context 'validates ports' do
        describe 'good' do
          context 'when ports is a range' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '8080-8081') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when ports is a comma separated list' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '8080, 8081') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when ports is a single value' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => ' 8080 ') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end
        end

        describe 'bad' do
          context 'when the ports contains non-integers' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => 'asdf') }

            it 'is not valid' do
              expect(subject).to_not be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid ports'
            end
          end

          context 'when the range is degenerate' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '1-1') }

            it 'is not valid' do
              expect(subject).to_not be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid ports'
            end
          end

          context 'when the range is not increasing' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '8-1') }

            it 'is not valid' do
              expect(subject).to_not be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid ports'
            end
          end

          context 'when the range is not valid' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '-1') }

            it 'is not valid' do
              expect(subject).to_not be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid ports'
            end
          end

          context 'when the range contains invalid ports' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '0-7') }

            it 'is not valid' do
              expect(subject).to_not be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid ports'
            end
          end

          context 'when the ports field contains two different formats' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '1-7,1') }

            it 'is not valid' do
              expect(subject).to_not be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid ports'
            end
          end

          context 'when the ports list contains an invalid port' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => '1,5,65536') }

            it 'is not valid' do
              expect(subject).to_not be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid ports'
            end
          end

          context 'when the ports range contains space padding' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'ports' => ' 1 - 4 ') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when it is missing' do
            let(:rule) do
              default_rule = build_transport_rule()
              default_rule.delete('ports')
              default_rule
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'ports\''
            end
          end
        end
      end

      context 'validates destination' do
        context 'good' do
          context 'when it is a valid CIDR' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0/0') }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end
        end

        context 'bad' do
          context 'when it contains non-CIDR characters' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => 'asdf') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains a non valid prefix mask' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.0.0.0/33') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it contains a non IP address' do
            let(:rule) { build_transport_rule('protocol' => protocol, 'destination' => '0.257.0.0/20') }

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
            end
          end

          context 'when it is missing' do
            let(:rule) do
              default_rule = build_transport_rule()
              default_rule.delete('destination')
              default_rule
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:rules].length).to eq 1
              expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'destination\''
            end
          end
        end
      end

      context 'when the rule contains extraneous fields' do
        let(:rule) { build_transport_rule('foobar' => 'asdf') }

        it 'is not valid' do
          expect(subject).to_not be_valid
          expect(subject.errors[:rules].length).to eq 1
          expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains the invalid field \'foobar\''
        end
      end
    end

    it_behaves_like 'a CloudController model', {
      many_to_zero_or_more: {
        spaces: ->(app_security_group) { Space.make }
      }
    }

    describe "Validations" do
      it { should validate_presence :name }
      it { should validate_uniqueness :name }

      context 'name' do
        subject(:app_sec_group) { AppSecurityGroup.make }

        it 'shoud allow standard ascii characters' do
          app_sec_group.name = "A -_- word 2!?()\'\"&+."
          expect {
            app_sec_group.save
          }.to_not raise_error
        end

        it 'should allow backslash characters' do
          app_sec_group.name = "a\\word"
          expect {
            app_sec_group.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          app_sec_group.name = "Ω∂∂ƒƒß√˜˙∆ß"
          expect {
            app_sec_group.save
          }.to_not raise_error
        end

        it 'should not allow newline characters' do
          app_sec_group.name = "one\ntwo"
          expect {
            app_sec_group.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape characters' do
          app_sec_group.name = "a\e word"
          expect {
            app_sec_group.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'rules' do
        let(:rule) { {} }

        before do
          subject.name = 'foobar'
          subject.rules = [ rule ]
        end

        context 'is an array of hashes' do
          context 'icmp rule' do
            context 'validates type' do
              context 'good' do
                context 'when the type is a valid 8 bit number' do
                  let (:rule) { build_icmp_rule('type' => 5) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when the type is -1' do
                  let (:rule) { build_icmp_rule('type' => -1) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end
              end

              context 'bad' do
                context 'when the type is non numeric' do
                  let(:rule) { build_icmp_rule('type' => 'asdf') }

                  it 'is not valid' do
                    expect(subject).to_not be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid type'
                  end
                end

                context 'when type cannot be represented in 8 bits' do
                  let(:rule) { build_icmp_rule('type' => 256) }

                  it 'is not valid' do
                    expect(subject).to_not be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid type'
                  end
                end

                context 'when it is missing' do
                  let(:rule) do
                    default_rule = build_icmp_rule()
                    default_rule.delete('type')
                    default_rule
                  end

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'type\''
                  end
                end
              end
            end

            context 'validates code' do
              context 'good' do
                context 'when the type is a valid 8 bit number' do
                  let (:rule) { build_icmp_rule('code' => 5) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end

                context 'when the type is -1' do
                  let (:rule) { build_icmp_rule('code' => -1) }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end
              end

              context 'bad' do
                context 'when the type is non numeric' do
                  let(:rule) { build_icmp_rule('code' => 'asdf') }

                  it 'is not valid' do
                    expect(subject).to_not be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid code'
                  end
                end

                context 'when type cannot be represented in 8 bits' do
                  let(:rule) { build_icmp_rule('code' => 256) }

                  it 'is not valid' do
                    expect(subject).to_not be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid code'
                  end
                end

                context 'when it is missing' do
                  let(:rule) do
                    default_rule = build_icmp_rule()
                    default_rule.delete('code')
                    default_rule
                  end

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'code\''
                  end
                end
              end
            end

            context 'validates destination' do
              context 'good' do
                context 'when it is a valid CIDR' do
                  let(:rule) { build_icmp_rule('destination' => '0.0.0.0/0') }

                  it 'is valid' do
                    expect(subject).to be_valid
                  end
                end
              end

              context 'bad' do
                context 'when it contains non-CIDR characters' do
                  let(:rule) { build_icmp_rule('destination' => 'asdf') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it contains a non valid prefix mask' do
                  let(:rule) { build_icmp_rule('destination' => '0.0.0.0/33') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it contains a invalid IP address' do
                  let(:rule) { build_icmp_rule('destination' => '0.257.0.0/20') }

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains invalid destination'
                  end
                end

                context 'when it is missing' do
                  let(:rule) do
                    default_rule = build_icmp_rule()
                    default_rule.delete('destination')
                    default_rule
                  end

                  it 'is not valid' do
                    expect(subject).not_to be_valid
                    expect(subject.errors[:rules].length).to eq 1
                    expect(subject.errors[:rules][0]).to start_with 'rule number 1 missing required field \'destination\''
                  end
                end
              end
            end

            context 'when the icmp rule contains extraneous fields' do
              let(:rule) { build_icmp_rule(foobar: "asdf") }

              it 'is not valid' do
                expect(subject).to_not be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains the invalid field \'foobar\''
              end
            end
          end

          context 'tcp rule' do
            it_behaves_like 'a transport rule' do
              let(:protocol) { 'tcp' }
            end
          end

          context 'udp rule' do
            it_behaves_like 'a transport rule' do
              let(:protocol) { 'udp' }
            end
          end

          context 'when a rule is not valid' do
            context 'when the protocol is unsupported' do
              let(:rule) { build_transport_rule('protocol' => 'foobar') }

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains an unsupported protocol'
              end
            end

            context 'when the protocol is not specified' do
              let(:rule) { {} }

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:rules].length).to eq 1
                expect(subject.errors[:rules][0]).to start_with 'rule number 1 contains an unsupported protocol'
              end
            end
          end
        end

        context 'when rules is not JSON' do
          before do
            subject.rules = '{omgbad}'
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:rules].length).to eq 1
            expect(subject.errors[:rules][0]).to start_with 'value must be an array of hashes'
          end
        end

        context 'when rules is not an array' do
          before do
            subject.rules = { "valid" => "json" }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:rules].length).to eq 1
            expect(subject.errors[:rules][0]).to start_with 'value must be an array of hashes'
          end
        end

        context 'when rules is not an array of hashes' do
          before do
            subject.rules = ["valid", "json"]
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:rules].length).to eq 1
            expect(subject.errors[:rules][0]).to start_with 'value must be an array of hashes'
          end
        end
      end
    end
  end
end
