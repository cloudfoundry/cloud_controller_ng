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

    let(:disabled_subject) { Client.new(hostname: hostname, port: port, enabled: false, trusted_cas: [], logger_name: 'perm', timeout: 0.1) }
    subject(:subject) { Client.new(hostname: hostname, port: port, enabled: true, trusted_cas: trusted_cas, logger_name: 'perm', timeout: 0.1) }

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
      it 'creates the correct role and creates associated permission' do
        subject.create_org_role(role: 'developer', org_id: org_id)

        expect(client).to have_received(:create_role).with(
          role_name: "org-developer-#{org_id}",
          permissions: [
            CloudFoundry::Perm::V1::Models::Permission.new(
              action: 'org.developer',
              resource_pattern: org_id.to_s
            )
          ]
        )
      end

      it 'does not fail if the role already exists' do
        allow(client).to receive(:create_role).and_raise(CloudFoundry::Perm::V1::Errors::AlreadyExists, '123')

        expect { subject.create_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:debug).with('create-role.role-already-exists', role: "org-developer-#{org_id}")
      end

      it 'does nothing when disabled' do
        disabled_subject.create_org_role(role: 'developer', org_id: org_id)

        expect(client).not_to have_received(:create_role)
      end

      it 'logs all other Perm errors' do
        allow(client).to receive(:create_role).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        expect { subject.create_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'create-role.bad-status',
          role: "org-developer-#{org_id}",
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:create_role).and_raise(StandardError)

        expect { subject.create_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'create-role.failed',
          anything)
      end
    end

    describe '#delete_org_role' do
      it 'deletes the correct role' do
        subject.delete_org_role(role: 'developer', org_id: org_id)

        expect(client).to have_received(:delete_role).with("org-developer-#{org_id}")
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:delete_role).and_raise(CloudFoundry::Perm::V1::Errors::NotFound, '123')

        expect { subject.delete_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:debug).with('delete-role.role-does-not-exist', role: "org-developer-#{org_id}")
      end

      it 'does nothing when disabled' do
        disabled_subject.delete_org_role(role: 'developer', org_id: org_id)

        expect(client).not_to have_received(:delete_role)
      end

      it 'logs all other Perm errors' do
        allow(client).to receive(:delete_role).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        expect { subject.delete_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'delete-role.bad-status',
          role: "org-developer-#{org_id}",
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          metadata: anything,
          details: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:delete_role).and_raise(StandardError)

        expect { subject.delete_org_role(role: 'developer', org_id: org_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'delete-role.failed',
          anything)
      end
    end

    describe '#assign_org_role' do
      it 'assigns the user to the role' do
        subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).to have_received(:assign_role).
          with(role_name: "org-developer-#{org_id}", actor_id: user_id, namespace: issuer)
      end

      it 'does not fail if the assignment already exists' do
        allow(client).to receive(:assign_role).and_raise(CloudFoundry::Perm::V1::Errors::AlreadyExists, '123')

        expect {
          subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:debug).with('assign-role.assignment-already-exists', role: "org-developer-#{org_id}", user_id: user_id, issuer: issuer)
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:assign_role).and_raise(CloudFoundry::Perm::V1::Errors::NotFound, '123')

        expect {
          subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with('assign-role.role-does-not-exist', role: "org-developer-#{org_id}", user_id: user_id, issuer: issuer)
      end

      it 'does nothing when disabled' do
        disabled_subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).not_to have_received(:assign_role)
      end

      it 'logs all other Perm errors' do
        allow(client).to receive(:assign_role).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        expect {
          subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'assign-role.bad-status',
          role: "org-developer-#{org_id}",
          user_id: user_id,
          issuer: issuer,
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:assign_role).and_raise(StandardError)

        expect {
          subject.assign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'assign-role.failed',
          anything)
      end
    end

    describe '#unassign_org_role' do
      it 'unassigns the user from the role' do
        subject.unassign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)

        expect(client).to have_received(:unassign_role).
          with(role_name: "org-developer-#{org_id}", actor_id: user_id, namespace: issuer)
      end

      it 'does not fail if something does not exist' do
        allow(client).to receive(:unassign_role).and_raise(CloudFoundry::Perm::V1::Errors::NotFound, '123')

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

      it 'logs all other Perm errors' do
        allow(client).to receive(:unassign_role).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        expect {
          subject.unassign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'unassign-role.bad-status',
          role: "org-developer-#{org_id}",
          user_id: user_id,
          issuer: issuer,
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:unassign_role).and_raise(StandardError)

        expect {
          subject.unassign_org_role(role: 'developer', org_id: org_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'unassign-role.failed',
          anything)
      end
    end

    describe '#unassign_roles' do
      let(:org_id2) { SecureRandom.uuid }
      let(:space_id2) { SecureRandom.uuid }

      it 'unassigns the user from all roles for the org and spaces' do
        subject.unassign_roles(org_ids: [org_id, org_id2], space_ids: [space_id, space_id2], user_id: user_id, issuer: issuer)

        [:user, :manager, :billing_manager, :auditor].each do |role|
          expect(client).to have_received(:unassign_role).
            with(role_name: "org-#{role}-#{org_id}", actor_id: user_id, namespace: issuer)
          expect(client).to have_received(:unassign_role).
            with(role_name: "org-#{role}-#{org_id2}", actor_id: user_id, namespace: issuer)
        end

        [:developer, :manager, :auditor].each do |role|
          expect(client).to have_received(:unassign_role).
            with(role_name: "space-#{role}-#{space_id}", actor_id: user_id, namespace: issuer)
          expect(client).to have_received(:unassign_role).
            with(role_name: "space-#{role}-#{space_id2}", actor_id: user_id, namespace: issuer)
        end
      end

      it 'does not fail if something does not exist' do
        allow(client).to receive(:unassign_role).and_raise(CloudFoundry::Perm::V1::Errors::NotFound, '123')

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

        expect(client).to have_received(:create_role).with(
          role_name: "space-developer-#{space_id}",
          permissions: [
            CloudFoundry::Perm::V1::Models::Permission.new(
              action: 'space.developer',
              resource_pattern: space_id.to_s
            )
          ]
        )
      end

      it 'does not fail if the role already exists' do
        allow(client).to receive(:create_role).and_raise(CloudFoundry::Perm::V1::Errors::AlreadyExists, '123')

        expect { subject.create_space_role(role: 'developer', space_id: space_id) }.not_to raise_error

        expect(logger).to have_received(:debug).with('create-role.role-already-exists', role: "space-developer-#{space_id}")
      end

      it 'does nothing when disabled' do
        disabled_subject.create_space_role(role: 'developer', space_id: space_id)

        expect(client).not_to have_received(:create_role)
      end

      it 'logs all other Perm errors' do
        allow(client).to receive(:create_role).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        expect { subject.create_space_role(role: 'developer', space_id: space_id) }.not_to raise_error
        expect(logger).to have_received(:error).with(
          'create-role.bad-status',
          role: "space-developer-#{space_id}",
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:create_role).and_raise(StandardError)

        expect { subject.create_space_role(role: 'developer', space_id: space_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'create-role.failed',
          anything)
      end
    end

    describe '#delete_space_role' do
      it 'deletes the correct role' do
        subject.delete_space_role(role: 'developer', space_id: space_id)

        expect(client).to have_received(:delete_role).with("space-developer-#{space_id}")
      end

      it 'does not fail if the role does not exist' do
        allow(client).to receive(:delete_role).and_raise(CloudFoundry::Perm::V1::Errors::NotFound, '123')

        expect { subject.delete_space_role(role: 'developer', space_id: space_id) }.not_to raise_error

        expect(logger).to have_received(:debug).with('delete-role.role-does-not-exist', role: "space-developer-#{space_id}")
      end

      it 'does nothing when disabled' do
        disabled_subject.delete_space_role(role: 'developer', space_id: space_id)

        expect(client).not_to have_received(:delete_role)
      end

      it 'logs all other Perm errors' do
        allow(client).to receive(:delete_role).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        expect { subject.delete_space_role(role: 'developer', space_id: space_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'delete-role.bad-status',
          role: "space-developer-#{space_id}",
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:delete_role).and_raise(StandardError)

        expect { subject.delete_space_role(role: 'developer', space_id: space_id) }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'delete-role.failed',
          anything)
      end
    end

    describe '#assign_space_role' do
      it 'assigns the user to the role' do
        subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)

        expect(client).to have_received(:assign_role).
          with(role_name: "space-developer-#{space_id}", actor_id: user_id, namespace: issuer)
      end

      it 'does not fail if the assignment already exists' do
        allow(client).to receive(:assign_role).and_raise(CloudFoundry::Perm::V1::Errors::AlreadyExists, '123')

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
        allow(client).to receive(:assign_role).and_raise(CloudFoundry::Perm::V1::Errors::NotFound, '123')

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

      it 'logs all other Perm errors' do
        allow(client).to receive(:assign_role).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        expect {
          subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'assign-role.bad-status',
          role: "space-developer-#{space_id}",
          user_id: user_id,
          issuer: issuer,
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:assign_role).and_raise(StandardError)

        expect {
          subject.assign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'assign-role.failed',
          anything)
      end
    end

    describe '#unassign_space_role' do
      it 'unassigns the user from the role' do
        subject.unassign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)

        expect(client).to have_received(:unassign_role).
          with(role_name: "space-developer-#{space_id}", actor_id: user_id, namespace: issuer)
      end

      it 'does not fail if something does not exist' do
        allow(client).to receive(:unassign_role).and_raise(CloudFoundry::Perm::V1::Errors::NotFound, '123')

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

      it 'logs all other Perm errors' do
        allow(client).to receive(:unassign_role).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        expect {
          subject.unassign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'unassign-role.bad-status',
          role: "space-developer-#{space_id}",
          user_id: user_id,
          issuer: issuer,
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:unassign_role).and_raise(StandardError)

        expect {
          subject.unassign_space_role(role: 'developer', space_id: space_id, user_id: user_id, issuer: issuer)
        }.not_to raise_error

        expect(logger).to have_received(:error).with(
          'unassign-role.failed',
          anything)
      end
    end

    describe '#has_permission?' do
      it 'returns true if the user has the permission' do
        allow(client).to receive(:has_permission?).with(action: 'space.developer', resource: space_id, actor_id: user_id, namespace: issuer).and_return(true)

        has_permission = subject.has_permission?(action: 'space.developer', resource: space_id, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(true)
      end

      it 'returns false if the user does not have the permission' do
        allow(client).to receive(:has_permission?).and_return(false)

        has_permission = subject.has_permission?(action: 'space.developer', resource: space_id, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(false)
      end

      it 'returns false if disabled' do
        has_permission = disabled_subject.has_permission?(action: 'space.developer', resource: space_id, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(false)

        expect(client).not_to have_received(:has_permission?)
      end

      it 'logs Perm errors and returns false' do
        allow(client).to receive(:has_permission?).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        has_permission = subject.has_permission?(action: 'space.developer', resource: space_id, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(false)
        expect(logger).to have_received(:error).with(
          'has-permission?.bad-status',
          action: 'space.developer',
          user_id: user_id,
          issuer: issuer,
          resource: space_id,
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:has_permission?).and_raise(StandardError)

        has_permission = subject.has_permission?(action: 'space.developer', resource: space_id, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(false)

        expect(logger).to have_received(:error).with(
          'has-permission?.failed',
          anything)
      end
    end

    describe '#has_any_permission?' do
      let(:permissions) {
        [
          { action: 'space.developer', resource: space_id },
          { action: 'org.manager', resource: org_id },
        ]
      }
      it 'returns true if the user has any of the permission' do
        allow(client).to receive(:has_permission?).with(action: 'space.developer', resource: space_id, actor_id: user_id, namespace: issuer).and_return(true)
        allow(client).to receive(:has_permission?).with(action: 'org.manager', resource: org_id, actor_id: user_id, namespace: issuer).and_return(false)

        has_permission = subject.has_any_permission?(permissions: permissions, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(true)
      end

      it 'returns false if the user does not have any of the permission' do
        allow(client).to receive(:has_permission?).and_return(false)

        has_permission = subject.has_any_permission?(permissions: permissions, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(false)
      end

      it 'returns false if disabled' do
        has_permission = disabled_subject.has_any_permission?(permissions: permissions, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(false)

        expect(client).not_to have_received(:has_permission?)
      end

      it 'logs Perm errors and returns false' do
        allow(client).to receive(:has_permission?).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        has_permission = subject.has_any_permission?(permissions: permissions, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(false)
        expect(logger).to have_received(:error).with(
          'has-permission?.bad-status',
          action: 'space.developer',
          user_id: user_id,
          issuer: issuer,
          resource: space_id,
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)

        expect(logger).to have_received(:error).with(
          'has-permission?.bad-status',
          action: 'org.manager',
          user_id: user_id,
          issuer: issuer,
          resource: org_id,
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything)
      end

      it 'logs all other errors' do
        allow(client).to receive(:has_permission?).and_raise(StandardError)

        has_permission = subject.has_any_permission?(permissions: permissions, user_id: user_id, issuer: issuer)

        expect(has_permission).to equal(false)
        expect(logger).to have_received(:error).with(
          'has-permission?.failed',
          anything).twice
      end
    end

    describe '#list_unique_resource_patterns' do
      let(:action1) { 'action1' }
      let(:action2) { 'action2' }
      let(:actions) { [action1, action2] }
      let(:resource_patterns1) { %w(action1_rp1 action1_rp2 action1_rp1) }
      let(:resource_patterns2) { %w(action2_rp1 action2_rp2 action2_rp2) }

      it 'returns an empty array if Perm is not enabled' do
        result = disabled_subject.list_unique_resource_patterns(user_id: user_id, issuer: issuer, actions: actions)

        expect(result).to have(0).items
        expect(client).not_to have_received(:list_resource_patterns)
      end

      it 'returns a unique list of resource patterns that the user has access to' do
        allow(client).to receive(:list_resource_patterns).with(actor_id: user_id, namespace: issuer, action: action1).
          and_return(resource_patterns1)
        allow(client).to receive(:list_resource_patterns).with(actor_id: user_id, namespace: issuer, action: action2).
          and_return(resource_patterns2)

        result = subject.list_unique_resource_patterns(user_id: user_id, issuer: issuer, actions: actions)

        expect(result).to match_array(%w(action1_rp1 action1_rp2 action2_rp1 action2_rp2))
      end

      it 'logs Perm errors and returns an empty array' do
        allow(client).to receive(:list_resource_patterns).and_raise(CloudFoundry::Perm::V1::Errors::BadStatus, '123')

        result = subject.list_unique_resource_patterns(user_id: user_id, issuer: issuer, actions: actions)

        expect(result).to have(0).items
        expect(logger).to have_received(:error).with(
          'list-resource-patterns.bad-status',
          user_id: user_id,
          issuer: issuer,
          actions: actions,
          status: 'CloudFoundry::Perm::V1::Errors::BadStatus',
          code: anything,
          details: anything,
          metadata: anything
        )
      end

      it 'logs non-Perm errors and returns an empty array' do
        allow(client).to receive(:list_resource_patterns).and_raise(StandardError, '123')

        result = subject.list_unique_resource_patterns(user_id: user_id, issuer: issuer, actions: actions)

        expect(result).to have(0).items
        expect(logger).to have_received(:error).with(
          'list-resource-patterns.failed',
          user_id: user_id,
          issuer: issuer,
          actions: actions,
          message: '123',
          backtrace: anything,
        )
      end
    end
  end
end
