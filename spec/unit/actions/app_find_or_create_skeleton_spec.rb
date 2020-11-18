require 'spec_helper'
require 'actions/app_find_or_create_skeleton'

module VCAP::CloudController
  RSpec.describe AppFindOrCreateSkeleton do
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'gooid', user_guid: 'amelia@cats.com') }
    let(:space) { Space.make }
    let(:name) { 'banana' }

    subject(:action) { AppFindOrCreateSkeleton.new(user_audit_info) }

    context 'when the app exists' do
      let(:message) { AppManifestMessage.create_from_yml({ name: name }) }
      let!(:app) { AppModel.make(name: name, space: space) }

      it 'returns the existing app' do
        expect(action.find_or_create(message: message, space: space)).to eq app
      end
    end

    context 'when the app does not exist' do
      context 'when the app is a buildpack app' do
        let(:message) { AppManifestMessage.create_from_yml({ name: name }) }

        it 'creates the app' do
          app = nil
          expect { app = action.find_or_create(message: message, space: space) }.
            to change { AppModel.count }.by(1)

          expect(app.name).to eq(name)
          expect(app.space).to eq(space)
          expect(app.reload.lifecycle_type).to eq(Lifecycles::BUILDPACK)
        end
      end

      context 'when the app is a docker app' do
        let(:message) { AppManifestMessage.create_from_yml({ name: name, docker: { image: 'my/image' } }) }

        it 'creates the app' do
          app = nil
          expect { app = action.find_or_create(message: message, space: space) }.
            to change { AppModel.count }.by(1)

          expect(app.name).to eq(name)
          expect(app.space).to eq(space)
          expect(app.lifecycle_type).to eq(Lifecycles::DOCKER)
        end
      end
    end
  end
end
