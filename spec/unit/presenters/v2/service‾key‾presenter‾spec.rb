require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ServiceKeyPresenter do
    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'some_relation_url' => 'http://example.com' } }
    let(:presenter) { ServiceKeyPresenter.new }
    let(:service_key) { VCAP::CloudController::ServiceKey.make }

    before do
      allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
    end

    describe '#entity_hash' do
      it 'returns the service key entity that contains the service_key_parameters_url' do
        set_current_user_as_admin

        expect(presenter.entity_hash(controller, service_key, opts, depth, parents, orphans)).to eq(
          {
            'name' => service_key.name,
            'service_instance_guid' => service_key.service_instance_guid,
            'credentials' => service_key.credentials,
            'some_relation_url' => 'http://example.com',
            'service_key_parameters_url' => "/v2/service_keys/#{service_key.guid}/parameters",
          }
        )
      end

      context 'credentials' do
        let(:developer) { make_developer_for_space(service_key.service_instance.space) }
        let(:auditor) { make_auditor_for_space(service_key.service_instance.space) }
        let(:user) { make_user_for_space(service_key.service_instance.space) }
        let(:manager) { make_manager_for_space(service_key.service_instance.space) }

        it 'does not redact creds for an admin' do
          set_current_user_as_admin
          expect(presenter.entity_hash(controller, service_key, opts, depth, parents, orphans)['credentials']).not_to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'does not redact creds for an admin with readonly access' do
          set_current_user_as_admin_read_only
          expect(presenter.entity_hash(controller, service_key, opts, depth, parents, orphans)['credentials']).not_to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'does not redact creds for a space developer' do
          set_current_user(developer)
          expect(presenter.entity_hash(controller, service_key, opts, depth, parents, orphans)['credentials']).not_to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'redacts creds for a space auditor' do
          set_current_user(auditor)
          expect(presenter.entity_hash(controller, service_key, opts, depth, parents, orphans)['credentials']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'redacts creds for a space user' do
          set_current_user(user)
          expect(presenter.entity_hash(controller, service_key, opts, depth, parents, orphans)['credentials']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end

        it 'redacts creds for a space manager' do
          set_current_user(manager)
          expect(presenter.entity_hash(controller, service_key, opts, depth, parents, orphans)['credentials']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end
      end
    end
  end
end
