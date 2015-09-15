require 'spec_helper'
require 'messages/apps_list_message'

module VCAP::CloudController
  describe AppsListMessage do
    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          AppsListMessage.new({
              names: [],
              guids: [],
              organization_guids: [],
              space_guids: [],
              page: 1,
              per_page: 5,
              order_by: 'created_at',
            })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        expect {
          AppsListMessage.new
        }.not_to raise_error
      end

      it 'does not accept a field not in this set' do
        expect {
          AppsListMessage.new({
              foobar: 'pants',
            })
        }.to(raise_error NoMethodError) do |e|
          expect(e.message).to include 'foobar='
        end
      end

      describe 'validations' do
        it 'validates names is an array' do
          params = AppsListMessage.new names: 'not array'
          expect(params.valid?).to be_falsey
          expect(params.errors[:names].length).to eq 1
        end

        it 'validates guids is an array' do
          params = AppsListMessage.new guids: 'not array'
          expect(params.valid?).to be_falsey
          expect(params.errors[:guids].length).to eq 1
        end

        it 'validates organization_guids is an array' do
          params = AppsListMessage.new organization_guids: 'not array'
          expect(params.valid?).to be_falsey
          expect(params.errors[:organization_guids].length).to eq 1
        end

        it 'validates space_guids is an array' do
          params = AppsListMessage.new space_guids: 'not array'
          expect(params.valid?).to be_falsey
          expect(params.errors[:space_guids].length).to eq 1
        end

        describe 'page' do
          it 'validates it is a number' do
            params = AppsListMessage.new page: 'not number'
            expect(params.valid?).to be_falsey
            expect(params.errors[:page].length).to eq 1
          end

          it 'is invalid if page is 0' do
            params = AppsListMessage.new page: 0
            expect(params.valid?).to be_falsey
            expect(params.errors[:page].length).to eq 1
          end

          it 'is invalid if page is negative' do
            params = AppsListMessage.new page: -1
            expect(params.valid?).to be_falsey
            expect(params.errors[:page].length).to eq 1
          end
        end

        describe 'per_page' do
          it 'validates it is a number' do
            params = AppsListMessage.new per_page: 'not number'
            expect(params.valid?).to be_falsey
            expect(params.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is 0' do
            params = AppsListMessage.new per_page: 0
            expect(params.valid?).to be_falsey
            expect(params.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is negative' do
            params = AppsListMessage.new per_page: -1
            expect(params.valid?).to be_falsey
            expect(params.errors[:per_page].length).to eq 1
          end
        end

        describe 'order_by' do
          describe 'valid values' do
            it 'created_at' do
              params = AppsListMessage.new order_by: 'created_at'
              expect(params.valid?).to be_truthy
            end

            it 'updated_at' do
              params = AppsListMessage.new order_by: 'updated_at'
              expect(params.valid?).to be_truthy
            end

            describe 'order direction' do
              it 'accepts valid values prefixed with "-"' do
                params = AppsListMessage.new order_by: '-updated_at'
                expect(params.valid?).to be_truthy
              end

              it 'accepts valid values prefixed with "+"' do
                params = AppsListMessage.new order_by: '+updated_at'
                expect(params.valid?).to be_truthy
              end
            end
          end

          it 'is invalid otherwise' do
            params = AppsListMessage.new order_by: '+foobar'
            expect(params.valid?).to be_falsey
            expect(params.errors[:order_by].length).to eq 1
          end
        end
      end
    end
  end
end
