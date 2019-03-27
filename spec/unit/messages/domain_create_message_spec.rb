require 'spec_helper'
require 'messages/domain_create_message'

module VCAP::CloudController
  RSpec.describe DomainCreateMessage do
    subject { DomainCreateMessage.new(params) }

    describe 'validations' do
      context 'when valid params are given' do
        let(:params) { { name: 'foobar.com' } }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when no params are given' do
        let(:params) {}
        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            unexpected: 'meow',
            name: 'example.com'
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'name' do
        MIN_DOMAIN_NAME_LENGTH = DomainCreateMessage::MINIMUM_FQDN_DOMAIN_LENGTH
        MAX_DOMAIN_NAME_LENGTH = DomainCreateMessage::MAXIMUM_FQDN_DOMAIN_LENGTH
        MAX_SUBDOMAIN_LENGTH = DomainCreateMessage::MAXIMUM_DOMAIN_LABEL_LENGTH

        context 'when not a string' do
          let(:params) do
            { name: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:name]).to include('must be a string')
          end
        end

        context 'when it is too short' do
          let(:params) { { name: 'B' * (MIN_DOMAIN_NAME_LENGTH - 1) } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to include "is too short (minimum is #{MIN_DOMAIN_NAME_LENGTH} characters)"
          end
        end

        context 'when it is too long' do
          let(:params) { { name: 'B' * (MAX_DOMAIN_NAME_LENGTH + 1) } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to include "is too long (maximum is #{MAX_DOMAIN_NAME_LENGTH} characters)"
          end
        end

        context 'when it does not contain a .' do
          let(:params) { { name: 'idontlikedots' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to match ['does not comply with RFC 1035 standards', 'must contain at least one "."']
          end
        end

        context 'when the subdomain is too long' do
          let(:params) { { name: 'B' * (MAX_SUBDOMAIN_LENGTH + 1) + '.example.com' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to include 'subdomains must each be at most 63 characters'
          end
        end

        context 'when it contains invalid characters' do
          let(:params) { { name: '_!@#$%^&*().swag' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to include 'must consist of alphanumeric characters and hyphens'
          end
        end

        context 'when it does not conform to RFC 1035' do
          let(:params) { { name: 'B' * (MAX_SUBDOMAIN_LENGTH + 1) + '.example.com' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to include 'does not comply with RFC 1035 standards'
          end
        end
      end

      context 'internal' do
        context 'when not a boolean' do
          let(:params) { { internal: 'banana' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:internal]).to include 'must be a boolean'
          end
        end
      end

      context 'relationships' do
        context 'relationships is not a hash' do
          let(:params) { { relationships: 'banana' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:relationships]).to include "'relationships' is not a hash"
          end
        end

        context 'when org is missing' do
          let(:params) do
            {
              name: 'name.com',
              relationships: {}
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships).any? { |e| e.include?('Organization must be structured like') }).to be(true)
          end
        end

        context 'when org has an invalid guid' do
          let(:params) do
            {
              name: 'name.com',
              relationships: { organization: { data: { guid: 32 } } },
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships).any? { |e| e.include?('Organization guid') }).to be(true)
          end
        end

        context 'when org is malformed' do
          let(:params) do
            {
              name: 'name.com',
              relationships: { organization: 'asdf' }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships).any? { |e| e.include?('Organization must be structured like') }).to be(true)
          end
        end

        context 'when additional keys are present' do
          let(:params) do
            {
              name: 'name.com',
              relationships: {
                organization: { data: { guid: 'guid' } },
                other: 'stuff'
              }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:relationships]).to include("Unknown field(s): 'other'")
          end
        end

        context 'when passed a valid relationship' do
          let(:params) do
            {
              name: 'name.com',
              relationships: {
                organization: { data: { guid: 'guid' } }
              }
            }
          end

          it 'makes the guid accessible' do
            expect(subject).to be_valid
            expect(subject.relationships_message.organization_guid).to eq('guid')
          end
        end
      end

      context 'relationships with internal' do
        let(:params) do
          {
            name: 'name.com',
            relationships: {
              organization: { data: { guid: 'guid' } }
            },
            internal: true
          }
        end

        it 'should be invalid' do
          expect(subject).to_not be_valid
          expect(subject.errors[:base]).to include('Can not associate an internal domain with an organization')
        end
      end
    end
  end
end
