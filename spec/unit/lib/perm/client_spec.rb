require 'securerandom'
require 'spec_helper'

module VCAP::CloudController::Perm
  RSpec.describe Client do
    let(:url) { 'https://perm.example.com' }
    let(:client) { spy(CloudFoundry::Perm::V1::Client) }
    let(:org_id) { SecureRandom.uuid }
    let(:space_id) { SecureRandom.uuid }
    let(:user_id) { SecureRandom.uuid }
    let(:issuer) { 'https://issuer.example.com/oauth/token' }

    let(:disabled_subject) { Client.new(url: url, enabled: false) }
    subject(:subject) { Client.new(url: url, enabled: true) }

    before do
      allow(CloudFoundry::Perm::V1::Client).to receive(:new).with(url: url).and_return(client)
    end

    describe '#create_org_role' do
      it 'creates the correct role' do
        subject.create_org_role(role: 'developer', org_id: org_id)

        expect(client).to have_received(:create_role).with("org-developer-#{org_id}")
      end

      it 'does not fail if the role already exists' do
        allow(client).to receive(:create_role).and_raise(GRPC::AlreadyExists)

        expect { subject.create_org_role(role: 'developer', org_id: org_id) }.not_to raise_error
      end

      it 'does nothing when disabled' do
        disabled_subject.create_org_role(role: 'developer', org_id: org_id)

        expect(client).not_to have_received(:create_role)
      end
    end

    describe '#delete_org_role' do
      it 'deletes the correct role' do
        subject.delete_org_role(role: 'developer', org_id: org_id)

        expect(client).to have_received(:delete_role).with("org-developer-#{org_id}")
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:delete_role).and_raise(GRPC::NotFound)

        expect { subject.delete_org_role(role: 'developer', org_id: org_id) }.not_to raise_error
      end

      it 'does nothing when disabled' do
        disabled_subject.delete_org_role(role: 'developer', org_id: org_id)

        expect(client).not_to have_received(:delete_role)
      end
    end

    describe '#assign_org_role' do
      it 'assigns the user to the role' do
        subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).to have_received(:assign_role).
          with(role_name: "org-developer-#{org_id}", actor_id: user_id, issuer: issuer)
      end

      it 'does not fail if the assignment already exists' do
        allow(client).to receive(:assign_role).and_raise(GRPC::AlreadyExists)

        expect {
          subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:assign_role).and_raise(GRPC::NotFound)

        expect {
          subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error
      end

      it 'does nothing when disabled' do
        disabled_subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:assign_role)
      end
    end

    describe '#unassign_org_role' do
      it 'unassigns the user from the role' do
        subject.unassign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).to have_received(:unassign_role).
          with(role_name: "org-developer-#{org_id}", actor_id: user_id, issuer: issuer)
      end

      it 'does not fail if something does not exist' do
        allow(client).to receive(:unassign_role).and_raise(GRPC::NotFound)

        expect {
          subject.unassign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error
      end

      it 'does nothing when disabled' do
        disabled_subject.unassign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:unassign_role)
      end
    end

    describe '#create_space_role' do
      it 'creates the correct role' do
        subject.create_space_role(role: 'developer', space_id: space_id)

        expect(client).to have_received(:create_role).with("space-developer-#{space_id}")
      end

      it 'does not fail if the role already exists' do
        allow(client).to receive(:create_role).and_raise(GRPC::AlreadyExists)

        expect { subject.create_space_role(role: 'developer', space_id: space_id) }.not_to raise_error
      end

      it 'does nothing when disabled' do
        disabled_subject.create_space_role(role: 'developer', space_id: space_id)

        expect(client).not_to have_received(:create_role)
      end
    end

    describe '#delete_space_role' do
      it 'deletes the correct role' do
        subject.delete_space_role(role: 'developer', space_id: space_id)

        expect(client).to have_received(:delete_role).with("space-developer-#{space_id}")
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:delete_role).and_raise(GRPC::NotFound)

        expect { subject.delete_space_role(role: 'developer', space_id: space_id) }.not_to raise_error
      end

      it 'does nothing when disabled' do
        disabled_subject.delete_space_role(role: 'developer', space_id: space_id)

        expect(client).not_to have_received(:delete_role)
      end
    end

    describe '#assign_space_role' do
      it 'assigns the user to the role' do
        subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)

        expect(client).to have_received(:assign_role).
          with(role_name: "space-developer-#{space_id}", actor_id: user_id, issuer: issuer)
      end

      it 'does not fail if the assignment already exists' do
        allow(client).to receive(:assign_role).and_raise(GRPC::AlreadyExists)

        expect {
          subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:assign_role).and_raise(GRPC::NotFound)

        expect {
          subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error
      end

      it 'does nothing when disabled' do
        disabled_subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:assign_role)
      end
    end

    describe '#unassign_space_role' do
      it 'unassigns the user from the role' do
        subject.unassign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)

        expect(client).to have_received(:unassign_role).
          with(role_name: "space-developer-#{space_id}", actor_id: user_id, issuer: issuer)
      end

      it 'does not fail if something does not exist' do
        allow(client).to receive(:unassign_role).and_raise(GRPC::NotFound)

        expect {
          subject.unassign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error
      end

      it 'does nothing when disabled' do
        disabled_subject.unassign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:unassign_role)
      end
    end
  end
end
