require 'spec_helper'

module VCAP::CloudController
  RSpec.describe QuotasServicesMessage do
    subject { QuotasServicesMessage.new(params) }

    describe 'services' do
      context 'invalid keys are passed in' do
        let(:params) do
          { bad_key: 'billy' }
        end

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'bad_key'")
        end
      end

      describe 'total_service_instances' do
        context 'when the type is a string' do
          let(:params) do
            { total_service_instances: 'bob' }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total service instances is not a number')
          end
        end
        context 'when the type is decimal' do
          let(:params) do
            { total_service_instances: 1.1 }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total service instances must be an integer')
          end
        end
        context 'when the type is a negative integer' do
          let(:params) do
            { total_service_instances: -1 }
          end

          it 'is not valid because "unlimited" is set with null, not -1, in V3' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total service instances must be greater than or equal to 0')
          end
        end

        context 'when the type is zero' do
          let(:params) do
            { total_service_instances: 0 }
          end

          it { is_expected.to be_valid }
        end
        context 'when the type is nil (unlimited)' do
          let(:params) do
            { total_service_instances: nil }
          end

          it { is_expected.to be_valid }
        end
        context 'when the value is greater than the maximum allowed value in the DB' do
          let(:params) do
            { total_service_instances: 1000000000000000000000000 }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total service instances must be less than or equal to 2147483647')
          end
        end
      end

      describe 'total_service_keys' do
        context 'when the type is a string' do
          let(:params) do
            { total_service_keys: 'bob' }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total service keys is not a number')
          end
        end
        context 'when the type is decimal' do
          let(:params) do
            { total_service_keys: 1.1 }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total service keys must be an integer')
          end
        end
        context 'when the type is a negative integer' do
          let(:params) do
            { total_service_keys: -1 }
          end

          it 'is not valid because "unlimited" is set with null, not -1, in V3' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total service keys must be greater than or equal to 0')
          end
        end

        context 'when the type is zero' do
          let(:params) do
            { total_service_keys: 0 }
          end

          it { is_expected.to be_valid }
        end
        context 'when the type is nil (unlimited)' do
          let(:params) do
            { total_service_keys: nil }
          end

          it { is_expected.to be_valid }
        end
        context 'when the value is greater than the maximum allowed value in the DB' do
          let(:params) do
            { total_service_keys: 1000000000000000000000000 }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total service keys must be less than or equal to 2147483647')
          end
        end
      end

      describe 'paid_services_allowed' do
        context 'when it is a boolean' do
          let(:params) do
            { paid_services_allowed: false }
          end

          it { is_expected.to be_valid }
        end

        context 'when it is not a boolean' do
          let(:params) do
            { paid_services_allowed: 'b' }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Paid services allowed must be a boolean')
          end
        end
      end
    end
  end
end
