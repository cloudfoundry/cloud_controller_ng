require 'spec_helper'
require 'messages/apps_droplets_list_message'

module VCAP::CloudController
  describe AppsDropletsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'states'    => 'state1,state2',
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'created_at'
        }
      end

      it 'returns the correct AppCreateMessage' do
        message = AppsDropletsListMessage.from_params(params)

        expect(message).to be_a(AppsDropletsListMessage)
        expect(message.states).to eq(['state1', 'state2'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
      end

      it 'converts requested keys to symbols' do
        message = AppsDropletsListMessage.from_params(params)

        expect(message.requested?(:states)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          states:    ['state'],
          page:      1,
          per_page:  5,
          order_by:  'created_at',
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:states]
        expect(AppsDropletsListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = AppsDropletsListMessage.new({
            states: [],
            page: 1,
            per_page: 5,
            order_by: 'created_at'
          })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = AppsDropletsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = DropletsListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        it 'validates states is an array' do
          message = AppsDropletsListMessage.new states: 'not array at all'
          expect(message).to be_invalid
          expect(message.errors[:states].length).to eq 1
        end

        describe 'page' do
          it 'validates it is a number' do
            message = AppsDropletsListMessage.new page: 'not number'
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is 0' do
            message = AppsDropletsListMessage.new page: 0
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is negative' do
            message = AppsDropletsListMessage.new page: -1
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is not an integer' do
            message = AppsDropletsListMessage.new page: 1.1
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end
        end

        describe 'per_page' do
          it 'validates it is a number' do
            message = AppsDropletsListMessage.new per_page: 'not number'
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is 0' do
            message = AppsDropletsListMessage.new per_page: 0
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is negative' do
            message = AppsDropletsListMessage.new per_page: -1
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is not an integer' do
            message = AppsDropletsListMessage.new per_page: 1.1
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end
        end

        describe 'order_by' do
          describe 'valid values' do
            it 'created_at' do
              message = AppsDropletsListMessage.new order_by: 'created_at'
              expect(message).to be_valid
            end

            it 'updated_at' do
              message = AppsDropletsListMessage.new order_by: 'updated_at'
              expect(message).to be_valid
            end

            describe 'order direction' do
              it 'accepts valid values prefixed with "-"' do
                message = AppsDropletsListMessage.new order_by: '-updated_at'
                expect(message).to be_valid
              end

              it 'accepts valid values prefixed with "+"' do
                message = AppsDropletsListMessage.new order_by: '+updated_at'
                expect(message).to be_valid
              end
            end
          end

          it 'is invalid otherwise' do
            message = AppsDropletsListMessage.new order_by: 123456
            expect(message).to be_invalid
            expect(message.errors[:order_by].length).to eq 1
          end
        end
      end
    end
  end
end
