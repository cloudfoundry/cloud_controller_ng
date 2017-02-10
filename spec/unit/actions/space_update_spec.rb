require 'spec_helper'
require 'actions/space_update'

module VCAP::CloudController
  RSpec.describe SpaceUpdate do
    subject(:space_update) { SpaceUpdate.new(user_audit_info) }

    let(:org_model) { Organization.make }
    let(:space_model) { Space.make(name: space_name, organization: org_model) }
    let(:user_guid) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }
    let(:space_name) { 'original name' }
    let(:isolation_segment) { IsolationSegmentModel.make }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    before do
      assigner.assign(isolation_segment, [org_model])
    end

    describe '#update' do
      let(:message) do
        SpaceUpdateMessage.create_from_http_request({
            data: { 'guid' => 'frank' }
          })
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::SpaceEventRepository).to receive(:record_space_update).with(
          space_model,
          user_audit_info,
          {
            'data' => { 'guid' => 'frank' }
          }
        )

        space_update.update(space_model, isolation_segment, message)
      end

      describe 'updating the iso seg' do
        let(:message) { SpaceUpdateMessage.new(data: { 'guid' => 'spicer' }) }

        it 'updates the spaces isolation segment' do
          expect(space_model.name).to eq(space_name)
          expect(space_model.isolation_segment_guid).to eq(nil)

          space_update.update(space_model, isolation_segment, message)
          space_model.reload

          expect(space_model.name).to eq(space_name)
          expect(space_model.isolation_segment_guid).to eq(isolation_segment.guid)
        end
      end

      context 'when the space is invalid' do
        before do
          allow(space_model).to receive(:save).and_raise(Sequel::ValidationFailed.new('something'))
        end

        it 'raises an invalid space error' do
          expect { space_update.update(space_model, isolation_segment, message) }.to raise_error(SpaceUpdate::InvalidSpace)
        end
      end
    end
  end
end
