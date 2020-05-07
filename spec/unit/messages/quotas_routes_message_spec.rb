require 'spec_helper'

module VCAP::CloudController
  RSpec.describe QuotasRoutesMessage do
    subject { QuotasRoutesMessage.new(params) }

    describe 'routes' do
      context 'invalid keys are passed in' do
        let(:params) do
          { bad_key: 'billy' }
        end

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'bad_key'")
        end
      end

      describe 'total_routes' do
        context 'when the type is a string' do
          let(:params) do
            { total_routes: 'bob' }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total routes is not a number')
          end
        end

        context 'when the type is decimal' do
          let(:params) do
            { total_routes: 1.1 }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total routes must be an integer')
          end
        end

        context 'when the type is a negative integer' do
          let(:params) do
            { total_routes: -1 }
          end

          it 'is not valid because "unlimited" is set with null, not -1, in V3' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total routes must be greater than or equal to 0')
          end
        end

        context 'when the type is zero' do
          let(:params) do
            { total_routes: 0 }
          end

          it { is_expected.to be_valid }
        end

        context 'when the type is nil (unlimited)' do
          let(:params) do
            { total_routes: nil }
          end

          it { is_expected.to be_valid }
        end

        context 'when the value is greater than the maximum allowed value in the DB' do
          let(:params) do
            { total_routes: 1000000000000000000000000 }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total routes must be less than or equal to 2147483647')
          end
        end
      end

      describe 'total_reserved_ports' do
        context 'when the type is a string' do
          let(:params) do
            { total_reserved_ports: 'bob' }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total reserved ports is not a number')
          end
        end

        context 'when the type is decimal' do
          let(:params) do
            { total_reserved_ports: 1.1 }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total reserved ports must be an integer')
          end
        end

        context 'when the type is a negative integer' do
          let(:params) do
            { total_reserved_ports: -1 }
          end

          it 'is not valid because "unlimited" is set with null, not -1, in V3' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total reserved ports must be greater than or equal to 0')
          end
        end

        context 'when the type is zero' do
          let(:params) do
            { total_reserved_ports: 0 }
          end

          it { is_expected.to be_valid }
        end

        context 'when the type is nil (unlimited)' do
          let(:params) do
            { total_reserved_ports: nil }
          end

          it { is_expected.to be_valid }
        end
        context 'when the value is greater than the maximum allowed value in the DB' do
          let(:params) do
            { total_reserved_ports: 1000000000000000000000000 }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors).to contain_exactly('Total reserved ports must be less than or equal to 2147483647')
          end
        end
      end
    end
  end
end
