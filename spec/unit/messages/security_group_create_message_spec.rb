require 'spec_helper'
require 'messages/security_group_create_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupCreateMessage do
    subject { SecurityGroupCreateMessage.new(params) }

    describe 'validating parameters' do
      context 'when valid params are given' do
        let(:params) {
          {
            'name' => 'some-name',
            'globally_enabled' => {
              'running' => true,
              'staging' => false
            },
            'relationships' => {
              'staging_spaces' => {
                'data' => [{
                  'guid' => 'some-space-guid'
                }]
              },
              'running_spaces' => {
                'data' => [{
                  'guid' => 'some-space-guid'
                }]
              }
            }
          }
        }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to contain_exactly "can't be blank", 'must be a string'
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
          let(:params) { { 'name' => 'thë-name' } }

          it { is_expected.to be_valid }
        end

        context 'when it contains hyphens' do
          let(:params) { { 'name' => 'a-z' } }

          it { is_expected.to be_valid }
        end

        context 'when it contains capital ascii' do
          let(:params) { { 'name' => 'AZ' } }

          it { is_expected.to be_valid }
        end

        context 'when it is at max length' do
          let(:params) { { 'name' => 'B' * SecurityGroupCreateMessage::MAX_SECURITY_GROUP_NAME_LENGTH } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { 'name' => 'B' * (SecurityGroupCreateMessage::MAX_SECURITY_GROUP_NAME_LENGTH + 1), } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to contain_exactly('is too long (maximum is 250 characters)')
          end
        end

        context 'when it is blank' do
          let(:params) { { 'name' => '' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to include("can't be blank")
          end
        end

        context 'when it is not a string' do
          let(:params) { { name: true } }

          it { is_expected.to be_invalid }
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

        context 'when rules are valid' do
          let(:rules) do
            [
              {
                protocol: 'tcp',
                destination: '10.10.10.0/24',
                ports: '443,80,8080'
              },
              {
                protocol: 'icmp',
                destination: '10.10.10.0/24',
                type: 8,
                code: 0,
                description: 'Allow ping requests to private services'
              },
            ]
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when rules are invalid' do
          let(:rules) do
            [
              {
                protocol: 'blah',
              },
              {
                'not-a-field': true,
              }
            ]
          end

          it 'is invalid' do
            expect(subject).to be_invalid
          end
        end
      end

      describe 'globally_enabled' do
        let(:globally_enabled) { {} }

        let(:params) do
          {
            'name' => 'basic',
            'globally_enabled' => globally_enabled
          }
        end

        context 'when no configuration is supplied' do
          context 'when value is not a hash' do
            let(:globally_enabled) { 'bad' }
            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:globally_enabled]).to eq(['must be an object'])
            end
          end

          context 'when the nested keys are invalid' do
            let(:globally_enabled) { { 'bad' => 'key' } }
            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:globally_enabled]).to eq(["only allows keys 'running' or 'staging'"])
            end
          end

          context 'when the values provided to running/staging is not a boolean' do
            let(:globally_enabled) { {
              'running' => 'value',
              'staging' => 'value',
            }
            }
            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:globally_enabled]).to eq(['values must be booleans'])
            end
          end
        end
      end

      describe 'relationships' do
        let(:params) do
          {
            'name' => 'basic',
            'relationships' => relationships
          }
        end

        context 'given no relationships' do
          let(:params) do
            {
              name: 'kris',
            }
          end

          it { is_expected.to be_valid }
        end

        context 'given a malformed staging space guid' do
          let(:params) do
            {
              name: 'rob',
              relationships: {
                staging_spaces: {
                  data: [{
                    guid: 150000
                  }],
                }
              }
            }
          end

          it { is_expected.to be_invalid }
        end

        context 'given unexpected staging spaces relationship data (not one-to-many relationship)' do
          let(:params) do
            {
              name: 'kim',
              relationships: {
                staging_spaces: {
                  data: { guid: 'skims' }
                }
              }
            }
          end

          it { is_expected.to be_invalid }
        end

        context 'given unexpected running spaces relationship data (not one-to-many relationship)' do
          let(:params) do
            {
              name: 'kim',
              relationships: {
                running_spaces: {
                  data: { guid: 'skims' }
                }
              }
            }
          end

          it { is_expected.to be_invalid }
        end

        context 'given a malformed running space guid' do
          let(:params) do
            {
              name: 'rob',
              relationships: {
                running_spaces: {
                  data: [
                    { guid: 150000 }
                  ]
                }
              }
            }
          end

          it { is_expected.to be_invalid }
        end
      end
    end

    describe '#running' do
      let(:params) {
        {
          name: 'some-name',
          globally_enabled: {
            running: true,
            staging: false
          }
        }
      }

      it 'returns the value provided for the running key' do
        expect(subject.running).to eq true
      end
    end

    describe '#staging' do
      let(:params) {
        {
          name: 'some-name',
          globally_enabled: {
            running: true,
            staging: false
          }
        }
      }

      it 'returns the value provided for the staging key' do
        expect(subject.staging).to eq false
      end
    end

    describe '#staging_space_guids' do
      let(:params) {
        {
          name: 'some-name',
          relationships: {
            staging_spaces: {
              data: [
                { guid: 'space-guid' }
              ]
            }
          }
        }
      }

      it 'returns the value provided for the staging key' do
        expect(subject.staging_space_guids).to eq ['space-guid']
      end
    end

    describe '#running_space_guids' do
      let(:params) {
        {
          name: 'some-name',
          relationships: {
            running_spaces: {
              data: [
                { guid: 'space-guid' }
              ]
            }
          }
        }
      }

      it 'returns the value provided for the staging key' do
        expect(subject.running_space_guids).to eq ['space-guid']
      end
    end
  end
end
