require 'spec_helper'
require 'actions/user_create'
require 'messages/user_create_message'

module VCAP::CloudController
  RSpec.describe UserCreate do
    subject { UserCreate.new }
    let(:guid) { 'some-user-guid' }
    let(:username) { 'some-username' }
    let(:origin) { 'some-origin' }
    let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }
    let(:metadata) do
      {
        labels: {
          'release' => 'stable',
          'seriouseats.com/potato' => 'mashed'
        },
        annotations: {
          'anno' => 'tations'
        }
      }
    end

    describe '#create' do
      context 'when there is a sequel validation error' do
        context 'when the error is a uniqueness error' do
          let(:existing_user) { User.make }
          let(:message) { UserCreateMessage.new({ guid: existing_user.guid, metadata: metadata }) }

          it 'returns an informative error message' do
            expect do
              subject.create(message:)
            end.to raise_error(UserCreate::Error, %(User with guid '#{existing_user.guid}' already exists.))
          end
        end
      end

      context 'when creating users concurrently' do
        let(:message) { UserCreateMessage.new({ guid: 'some-nice-user-gu-id' }) }

        it 'ensures one creation is successful and the other fails due to name conflict' do
          # First request, should succeed
          expect do
            subject.create(message:)
          end.not_to raise_error

          # Mock the validation for the second request to simulate the race condition and trigger a unique constraint violation
          allow_any_instance_of(User).to receive(:validate).and_return(true)

          # Second request, should fail with correct error
          expect do
            subject.create(message:)
          end.to raise_error(UserCreate::Error, "User with guid 'some-nice-user-gu-id' already exists.")
        end
      end

      describe 'creating users' do
        before do
          allow(User).to receive_messages(create_uaa_shadow_user: { 'id' => guid }, get_user_id_by_username_and_origin: nil)
        end

        context 'when creating a UAA user by guid' do
          let(:message) do
            UserCreateMessage.new({ guid:, metadata: })
          end

          it 'creates a user in ccdb' do
            created_user = nil
            expect do
              created_user = subject.create(message:)
            end.to change(User, :count).by(1)

            expect(created_user.guid).to eq guid
            expect(created_user).to have_labels(
              { prefix: nil, key_name: 'release', value: 'stable' },
              { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' }
            )
            expect(created_user).to have_annotations({ key_name: 'anno', value: 'tations' })
          end

          it 'does not create a shadow user in uaa' do
            subject.create(message:)
            expect(User).not_to have_received(:create_uaa_shadow_user)
          end
        end

        context 'when creating a UAA user by username and origin' do
          let(:message) do
            UserCreateMessage.new({ username:, origin:, metadata: })
          end

          it 'creates a user in ccdb' do
            created_user = nil
            expect do
              created_user = subject.create(message:)
            end.to change(User, :count).by(1)

            expect(created_user.guid).to eq guid
            expect(created_user).to have_labels(
              { prefix: nil, key_name: 'release', value: 'stable' },
              { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' }
            )
            expect(created_user).to have_annotations({ key_name: 'anno', value: 'tations' })
          end

          it 'creates a shadow user in uaa' do
            subject.create(message:)
            expect(User).to have_received(:create_uaa_shadow_user).with(username, origin)
          end

          context 'when user already exists in UAA' do
            before do
              allow(User).to receive(:get_user_id_by_username_and_origin).and_return('some-user-guid')
            end

            it 'does not try to create a shadow user' do
              subject.create(message:)
              expect(User).not_to have_received(:create_uaa_shadow_user)
            end
          end

          context 'when an UaaUnavailable error is raised' do
            before do
              allow(User).to receive(:create_uaa_shadow_user).and_raise(UaaUnavailable)
            end

            it 'raises the error' do
              expect { subject.create(message:) }.to raise_error(UaaUnavailable)
            end
          end
        end

        context 'when creating a UAA client' do
          let(:client_id) { 'cc_routing' }

          let(:message) do
            UserCreateMessage.new({ guid: client_id, metadata: metadata })
          end

          it 'creates a user' do
            created_user = nil
            expect do
              created_user = subject.create(message:)
            end.to change(User, :count).by(1)

            expect(created_user.guid).to eq client_id
          end
        end
      end
    end
  end
end
