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
    end
  end
end
