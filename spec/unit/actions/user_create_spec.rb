require 'spec_helper'
require 'actions/user_create'
require 'messages/user_create_message'

module VCAP::CloudController
  RSpec.describe UserCreate do
    subject { UserCreate.new }
    let(:guid) { 'some-user-guid' }

    describe '#create' do
      context 'when there is a sequel validation error' do
        context 'when the error is a uniqueness error' do
          let(:existing_user) { User.make }
          let(:message) { UserCreateMessage.new({ guid: existing_user.guid }) }

          it 'returns an informative error message' do
            expect {
              subject.create(message: message)
            }.to raise_error(UserCreate::Error, %{User with guid '#{existing_user.guid}' already exists.})
          end
        end
      end

      context 'when creating a user' do
        let(:message) do
          UserCreateMessage.new({ guid: guid })
        end

        it 'creates a user' do
          expect {
            subject.create(message: message)
          }.to change { User.count }.by(1)

          user = User.last
          expect(user.guid).to eq guid
        end
      end
    end
  end
end
