require 'spec_helper'
require 'messages/droplets_list_message'

module VCAP::CloudController
  describe DropletsListMessage do
    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          DropletsListMessage.new({
              app_guids: [],
              states: [],
              page: 1,
              per_page: 5,
              order_by: 'created_at',
            })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        expect {
          DropletsListMessage.new
        }.not_to raise_error
      end

      it 'does not accept a field not in this set' do
        expect {
          DropletsListMessage.new({
              foobar: 'pants',
            })
        }.to(raise_error NoMethodError) do |e|
          expect(e.message).to include 'foobar='
        end
      end

      describe 'validations' do
        it 'validates app_guids is an array' do
          message = DropletsListMessage.new app_guids: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:app_guids].length).to eq 1
        end

        it 'validates states is an array' do
          message = DropletsListMessage.new states: 'not array at all'
          expect(message).to be_invalid
          expect(message.errors[:states].length).to eq 1
        end

        describe 'page' do
          it 'validates it is a number' do
            message = DropletsListMessage.new page: 'not number'
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is 0' do
            message = DropletsListMessage.new page: 0
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is negative' do
            message = DropletsListMessage.new page: -1
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end
        end

        describe 'per_page' do
          it 'validates it is a number' do
            message = DropletsListMessage.new per_page: 'not number'
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is 0' do
            message = DropletsListMessage.new per_page: 0
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is negative' do
            message = DropletsListMessage.new per_page: -1
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end
        end

        describe 'order_by' do
          describe 'valid values' do
            it 'created_at' do
              message = DropletsListMessage.new order_by: 'created_at'
              expect(message).to be_valid
            end

            it 'updated_at' do
              message = DropletsListMessage.new order_by: 'updated_at'
              expect(message).to be_valid
            end

            describe 'order direction' do
              it 'accepts valid values prefixed with "-"' do
                message = DropletsListMessage.new order_by: '-updated_at'
                expect(message).to be_valid
              end

              it 'accepts valid values prefixed with "+"' do
                message = DropletsListMessage.new order_by: '+updated_at'
                expect(message).to be_valid
              end
            end
          end

          it 'is invalid otherwise' do
            message = DropletsListMessage.new order_by: '+foobar'
            expect(message).to be_invalid
            expect(message.errors[:order_by].length).to eq 1
          end
        end
      end
    end
  end
end
