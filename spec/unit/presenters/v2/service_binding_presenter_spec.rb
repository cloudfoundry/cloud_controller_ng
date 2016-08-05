require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ServiceBindingPresenter do
    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_url' => 'http://relationship.example.com' } }
    subject { described_class.new }

    describe '#entity_hash' do
      before do
        set_current_user_as_admin
      end

      let(:volume_mount) { [{ 'my-volume-mount' => 'mount' }] }
      let(:service_binding) do
        VCAP::CloudController::ServiceBinding.make(
          credentials:      { 'secret' => 'key' },
          syslog_drain_url: 'syslog://drain.example.com',
          volume_mounts:    volume_mount
        )
      end

      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      it 'returns the service binding entity' do
        expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)).to eq(
          {
            'app_guid'              => service_binding.app.guid,
            'service_instance_guid' => service_binding.service_instance.guid,
            'credentials'           => { 'secret' => 'key' },
            'binding_options'       => {},
            'gateway_data'          => nil,
            'gateway_name'          => '',
            'syslog_drain_url'      => 'syslog://drain.example.com',
            'volume_mounts'         => [{ 'my-volume-mount' => 'mount' }],
            'relationship_url'      => 'http://relationship.example.com'
          }
        )
      end

      describe 'volume mounts' do
        context 'when they have a private key' do
          let(:volume_mount) do
            [
              { 'my-volume-mount' => 'mount', 'private' => { 'secret-stuff' => 'secret-thing' } },
              { 'other_mount' => 'mount', 'private' => { 'secret-stuff' => 'secret-thing' } },
            ]
          end

          it 'redacts "private" key' do
            expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['volume_mounts']).to eq(
              [{ 'my-volume-mount' => 'mount' }, { 'other_mount' => 'mount' }]
            )
          end
        end

        context 'when they are nil' do
          let(:volume_mount) { nil }

          it 'presents an empty array' do
            expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['volume_mounts']).to eq([])
          end
        end

        context 'when they are an empty string' do
          let(:volume_mount) { '' }

          it 'presents an empty array' do
            expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['volume_mounts']).to eq([])
          end
        end
      end

      describe 'credentials' do
        let(:developer) { make_developer_for_space(service_binding.service_instance.space) }
        let(:auditor) { make_auditor_for_space(service_binding.service_instance.space) }
        let(:user) { make_user_for_space(service_binding.service_instance.space) }
        let(:manager) { make_manager_for_space(service_binding.service_instance.space) }

        it 'does not redact creds for an admin' do
          set_current_user_as_admin
          expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['credentials']).not_to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'does not redact creds for an admin with readonly access' do
          set_current_user_as_admin_read_only
          expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['credentials']).not_to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'does not redact creds for a space developer' do
          set_current_user(developer)
          expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['credentials']).not_to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'redacts creds for a space auditor' do
          set_current_user(auditor)
          expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['credentials']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'redacts creds for a space user' do
          set_current_user(user)
          expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['credentials']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'redacts creds for a space manager' do
          set_current_user(manager)
          expect(subject.entity_hash(controller, service_binding, opts, depth, parents, orphans)['credentials']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end
      end
    end
  end
end
