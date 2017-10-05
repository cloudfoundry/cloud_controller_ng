require 'securerandom'
require 'spec_helper'

module VCAP::CloudController::Perm
  RSpec.describe Client do
    let(:hostname) { 'https://perm.example.com' }
    let(:port) { 5678 }
    let(:client) { spy(CloudFoundry::Perm::V1::Client) }
    let(:org_id) { SecureRandom.uuid }
    let(:space_id) { SecureRandom.uuid }
    let(:user_id) { SecureRandom.uuid }
    let(:issuer) { 'https://issuer.example.com/oauth/token' }
    let(:ca_cert_path) { File.join(Paths::FIXTURES, 'certs/perm_ca.crt') }
    let(:trusted_cas) { [File.open(ca_cert_path).read] }

    let(:logger) { instance_double(Steno::Logger) }

    let(:disabled_subject) { Client.new(hostname: hostname, port: port, enabled: false, trusted_cas: [], logger_name: 'perm') }
    subject(:subject) { Client.new(hostname: hostname, port: port, enabled: true, trusted_cas: trusted_cas, logger_name: 'perm') }

    before do
      allow(CloudFoundry::Perm::V1::Client).to receive(:new).with(hostname: hostname, port: port, trusted_cas: trusted_cas, timeout: anything).and_return(client)

      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:error)

      allow(subject).to receive(:logger).and_return(logger)
      allow(disabled_subject).to receive(:logger).and_return(logger)
      allow(client).to receive(:logger).and_return(logger)
    end

    describe '#create_org_role' do
      it 'creates the correct role' do
        subject.create_org_role(role: 'developer', org_id: org_id)

        expect(client).to have_received(:create_role).with("org-developer-#{org_id}")
      end

      it 'does not fail if the role already exists' do
        allow(client).to receive(:create_role).and_raise(GRPC::AlreadyExists)

        expect { subject.create_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:debug).with('create-role.role-already-exists', role: "org-developer-#{org_id}")
      end

      it 'does nothing when disabled' do
        disabled_subject.create_org_role(role: 'developer', org_id: org_id)

        expect(client).not_to have_received(:create_role)
      end

      it 'logs all other GRPC errors' do
        allow(client).to receive(:create_role).and_raise(GRPC::Unavailable)

        expect { subject.create_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'create-role.bad-status',
          role: "org-developer-#{org_id}",
          status: 'GRPC::Unavailable',
          code: anything,
          details: anything,
          metadata: anything)
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

        expect(logger).to have_received(:debug).with('delete-role.role-does-not-exist', role: "org-developer-#{org_id}")
      end

      it 'does nothing when disabled' do
        disabled_subject.delete_org_role(role: 'developer', org_id: org_id)

        expect(client).not_to have_received(:delete_role)
      end

      it 'logs all other GRPC errors' do
        allow(client).to receive(:delete_role).and_raise(GRPC::Unavailable)

        expect { subject.delete_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'delete-role.bad-status',
          role: "org-developer-#{org_id}",
          status: 'GRPC::Unavailable',
          code: anything,
          metadata: anything,
          details: anything)
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

        expect(logger).to have_received(:debug).with('assign-role.assignment-already-exists', role: "org-developer-#{org_id}", user_id: user_id, issuer: issuer)
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:assign_role).and_raise(GRPC::NotFound)

        expect {
          subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with('assign-role.role-does-not-exist', role: "org-developer-#{org_id}", user_id: user_id, issuer: issuer)
      end

      it 'does nothing when disabled' do
        disabled_subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:assign_role)
      end

      it 'logs all other GRPC errors' do
        allow(client).to receive(:assign_role).and_raise(GRPC::Unavailable)

        expect {
          subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'assign-role.bad-status',
          role: "org-developer-#{org_id}",
          user_id: user_id,
          issuer: issuer,
          status: 'GRPC::Unavailable',
          code: anything,
          details: anything,
          metadata: anything)
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

        expect(logger).to have_received(:error).with(
          'unassign-role.resource-not-found',
          role: "org-developer-#{org_id}",
          user_id: user_id,
          issuer: issuer,
          details: anything,
          metadata: anything)
      end

      it 'does nothing when disabled' do
        disabled_subject.unassign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:unassign_role)
      end

      it 'logs all other GRPC errors' do
        allow(client).to receive(:unassign_role).and_raise(GRPC::Unavailable)

        expect {
          subject.unassign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'unassign-role.bad-status',
          role: "org-developer-#{org_id}",
          user_id: user_id,
          issuer: issuer,
          status: 'GRPC::Unavailable',
          code: anything,
          details: anything,
          metadata: anything)
      end
    end

    describe '#unassign_roles' do
      let(:org_id2) { SecureRandom.uuid }
      let(:space_id2) { SecureRandom.uuid }

      it 'unassigns the user from all roles for the org and spaces' do
        subject.unassign_roles(org_ids: [org_id, org_id2], space_ids: [space_id, space_id2], user_id: user_id, issuer: issuer)

        [:user, :manager, :billing_manager, :auditor].each do |role|
          expect(client).to have_received(:unassign_role).
            with(role_name: "org-#{role}-#{org_id}", actor_id: user_id, issuer: issuer)
          expect(client).to have_received(:unassign_role).
            with(role_name: "org-#{role}-#{org_id2}", actor_id: user_id, issuer: issuer)
        end

        [:developer, :manager, :auditor].each do |role|
          expect(client).to have_received(:unassign_role).
            with(role_name: "space-#{role}-#{space_id}", actor_id: user_id, issuer: issuer)
          expect(client).to have_received(:unassign_role).
            with(role_name: "space-#{role}-#{space_id2}", actor_id: user_id, issuer: issuer)
        end
      end

      it 'does not fail if something does not exist' do
        allow(client).to receive(:unassign_role).and_raise(GRPC::NotFound)

        expect {
          subject.unassign_roles(org_ids: [org_id], space_ids: [space_id], user_id: user_id, issuer: issuer)
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

        expect(logger).to have_received(:debug).with('create-role.role-already-exists', role: "space-developer-#{space_id}")
      end

      it 'does nothing when disabled' do
        disabled_subject.create_space_role(role: 'developer', space_id: space_id)

        expect(client).not_to have_received(:create_role)
      end

      it 'logs all other GRPC errors' do
        allow(client).to receive(:create_role).and_raise(GRPC::Unavailable)

        expect { subject.create_space_role(role: 'developer', space_id: space_id) }.not_to raise_error
        expect(logger).to have_received(:error).with(
          'create-role.bad-status',
          role: "space-developer-#{space_id}",
          status: 'GRPC::Unavailable',
          code: anything,
          details: anything,
          metadata: anything)
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

        expect(logger).to have_received(:debug).with('delete-role.role-does-not-exist', role: "space-developer-#{space_id}")
      end

      it 'does nothing when disabled' do
        disabled_subject.delete_space_role(role: 'developer', space_id: space_id)

        expect(client).not_to have_received(:delete_role)
      end

      it 'logs all other GRPC errors' do
        allow(client).to receive(:delete_role).and_raise(GRPC::Unavailable)

        expect { subject.delete_space_role(role: 'developer', space_id: space_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'delete-role.bad-status',
          role: "space-developer-#{space_id}",
          status: 'GRPC::Unavailable',
          code: anything,
          details: anything,
          metadata: anything)
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

        expect(logger).to have_received(:debug).with(
          'assign-role.assignment-already-exists',
          role: "space-developer-#{space_id}",
          user_id: user_id,
          issuer: issuer)
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:assign_role).and_raise(GRPC::NotFound)

        expect {
          subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'assign-role.role-does-not-exist',
          role: "space-developer-#{space_id}",
          user_id: user_id,
          issuer: issuer)
      end

      it 'does nothing when disabled' do
        disabled_subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:assign_role)
      end

      it 'logs all other GRPC errors' do
        allow(client).to receive(:assign_role).and_raise(GRPC::Unavailable)

        expect {
          subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'assign-role.bad-status',
          role: "space-developer-#{space_id}",
          user_id: user_id,
          issuer: issuer,
          status: 'GRPC::Unavailable',
          code: anything,
          details: anything,
          metadata: anything)
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

        expect(logger).to have_received(:error).with(
          'unassign-role.resource-not-found',
          role: "space-developer-#{space_id}",
          user_id: user_id,
          issuer: issuer,
          details: anything,
          metadata: anything)
      end

      it 'does nothing when disabled' do
        disabled_subject.unassign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:unassign_role)
      end

      it 'logs all other GRPC errors' do
        allow(client).to receive(:unassign_role).and_raise(GRPC::Unavailable)

        expect {
          subject.unassign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'unassign-role.bad-status',
          role: "space-developer-#{space_id}",
          user_id: user_id,
          issuer: issuer,
          status: 'GRPC::Unavailable',
          code: anything,
          details: anything,
          metadata: anything)
      end
    end
  end
end
