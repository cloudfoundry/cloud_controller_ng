require 'spec_helper'
require 'messages/security_group_update_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupUpdateMessage do
    subject { SecurityGroupUpdateMessage.new(params) }

    let(:params) do
      {
        name: 'security-group-name',
        globally_enabled: {
          running: true,
          staging: false,
        },
        rules: rules,
      }
    end

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

    context 'when given valid params' do
      it 'successfully validates the inputs' do
        expect(subject).to be_valid
      end

      it 'populates the fields on the message' do
        expect(subject.name).to eq('security-group-name')
        expect(subject.running).to eq(true)
        expect(subject.staging).to eq(false)
        expect(subject.rules).to eq(rules)
      end
    end

    context 'when unexpected keys are requested' do
      let(:params) { { unexpected: 'meow' } }

      it 'is not valid' do
        expect(subject).not_to be_valid
        expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end
    end

    context 'when there are no params' do
      let(:params) { {} }

      it 'the message is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when there are partial params' do
      context 'when name is missing' do
        let(:params) do
          {
            globally_enabled: {
              running: true,
              staging: false,
            },
            rules: rules,
          }
        end

        it 'the message is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when globally_enabled is missing' do
        let(:params) do
          {
            name: 'security-group-name',
            rules: rules,
          }
        end

        it 'the message is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when rules are missing' do
        let(:params) do
          {
            name: 'security-group-name',
            globally_enabled: {
              running: true,
              staging: false,
            },
          }
        end

        it 'the message is valid' do
          expect(subject).to be_valid
        end
      end
    end

    context 'when the requested name is invalid' do
      context 'and the name is not alphanumeric' do
        let(:params) { { name: 123 } }

        it 'raises a validation error' do
          expect(subject).to be_invalid
        end
      end

      context 'and the name is too long' do
        let(:params) { { name: 'B' * (OrganizationQuotasUpdateMessage::MAX_ORGANIZATION_QUOTA_NAME_LENGTH + 1) } }

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors[:name]).to contain_exactly('is too long (maximum is 250 characters)')
        end
      end

      context 'and the name is blank' do
        let(:params) { { name: '' } }

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors[:name]).to eq ['is too short (minimum is 1 character)']
        end
      end
    end

    context 'when the requested rules are invalid' do
      let(:rules) do
        [
          {
            protocol: 'blah',
          },
        ]
      end

      it 'is invalid' do
        expect(subject).to be_invalid
      end
    end

    context 'when the requested globally_enabled settings are invalid' do
      let(:params) do
        {
          globally_enabled: {
            bad: 'invalid',
            alsobad: 'also-invalid',
          },
        }
      end

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors[:globally_enabled]).to eq(["only allows keys 'running' or 'staging'"])
      end
    end
  end
end
