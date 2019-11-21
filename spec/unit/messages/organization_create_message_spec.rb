require 'spec_helper'
require 'messages/organization_update_message'

module VCAP::CloudController
  RSpec.describe OrganizationCreateMessage do
    let(:body) do
      {
        'name' => 'my-org',
        'metadata' => {
          'labels' => {
            'potatoes' => 'orgTots'
          }
        }
      }
    end

    describe 'validations' do
      describe 'name' do
        it 'must be present' do
          body = {}
          message = OrganizationCreateMessage.new(body)
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Name can't be blank")
        end
      end

      describe 'metadata' do
        context 'when the annotations params are valid' do
          let(:params) do
            {
              'name' => 'potato-org',
              'metadata' => {
                'annotations' => {
                  'potato' => 'mashed'
                }
              }
            }
          end

          it 'is valid and correctly parses the annotations' do
            message = OrganizationCreateMessage.new(params)
            expect(message).to be_valid
            expect(message.annotations).to include(potato: 'mashed')
          end
        end

        context 'when the annotations params are not valid' do
          let(:params) do
            {
              'name' => 'tim-org',
              'metadata' => {
                'annotations' => 'timmyd'
              }
            }
          end

          it 'is invalid' do
            message = OrganizationCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include('\'annotations\' is not an object')
          end
        end
      end
    end
  end
end
