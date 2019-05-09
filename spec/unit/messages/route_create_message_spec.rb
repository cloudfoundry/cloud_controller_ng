require 'spec_helper'
require 'messages/route_create_message'

module VCAP::CloudController
  RSpec.describe RouteCreateMessage do
    subject { RouteCreateMessage.new(params) }

    describe 'validations' do
      context 'when valid params are given' do
        let(:params) do
          {
            relationships: {
              space: { data: { guid: 'space-guid' } },
              domain: { data: { guid: 'domain-guid' } },
            }
          }
        end

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:relationships]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            relationships: {
              space: { data: { guid: 'space-guid' } },
              domain: { data: { guid: 'domain-guid' } },
            },
            unexpected: 'meow',
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
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

        context 'when space is missing' do
          let(:params) do
            {
              relationships: {}
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include("'relationships' must include one or more valid relationships")
          end
        end

        context 'when space has an invalid guid' do
          let(:params) do
            {
              relationships: { space: { data: { guid: 32 } } },
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Space guid'))
          end
        end

        context 'when space is malformed' do
          let(:params) do
            {
              relationships: { space: 'asdf' }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Space must be structured like'))
          end
        end

        context 'when domain has an invalid guid' do
          let(:params) do
            {
              relationships: { domain: { data: { guid: 32 } } },
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Domain guid'))
          end
        end

        context 'when domain is malformed' do
          let(:params) do
            {
              relationships: { domain: 'asdf' }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Domain must be structured like'))
          end
        end

        context 'when additional keys are present' do
          let(:params) do
            {
              relationships: {
                space: { data: { guid: 'guid' } },
                other: 'stuff'
              }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:relationships]).to include("Unknown field(s): 'other'")
          end
        end
      end
    end

    describe 'accessor methods' do
      let(:params) do
        {
          relationships: {
            space: { data: { guid: 'space-guid' } },
            domain: { data: { guid: 'domain-guid' } },
          }
        }
      end

      context 'space_guid' do
        it 'makes the guid accessible' do
          expect(subject).to be_valid
          expect(subject.space_guid).to eq('space-guid')
        end
      end

      context 'domain_guid' do
        it 'makes the guid accessible' do
          expect(subject).to be_valid
          expect(subject.domain_guid).to eq('domain-guid')
        end
      end
    end
  end
end
