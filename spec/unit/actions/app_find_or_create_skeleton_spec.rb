require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppFindOrCreateSkeleton do
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'gooid', user_guid: 'amelia@cats.com') }
    let(:space) { Space.make }
    let(:name) { 'banana' }
    let(:message) { NamedAppManifestMessage.new({}, { name: name }) }

    subject(:action) { AppFindOrCreateSkeleton.new(user_audit_info) }

    context 'when the app exists' do
      let!(:app) { AppModel.make(name: name, space: space) }

      it 'returns the existing app' do
        expect(action.find_or_create(message: message, space: space)).to eq app
      end
    end

    context 'when the app does not exist' do
      it 'creates the app' do
        app = nil
        expect { app = action.find_or_create(message: message, space: space) }.
          to change { AppModel.count }.by(1)

        expect(app.name).to eq(name)
        expect(app.space).to eq(space)
      end
    end
  end
end
