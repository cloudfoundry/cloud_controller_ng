require 'spec_helper'

module VCAP::CloudController
  describe AppModelAccess, type: :access do
    let(:token) { {} }
    let(:admin) { false }
    let(:user) { User.make }
    let(:roles) { double(:roles, admin?: admin) }
    let(:app_model) { AppModel.make }
    let(:access_context) { double(:access_context, roles: roles, user: user) }

    before do
      SecurityContext.set(nil, token)
    end

    after do
      SecurityContext.clear
    end

    describe 'read?' do
      context 'admin user' do
        let(:admin) { true }

        it 'allows the user to read' do
          access_control = AppModelAccess.new(access_context)
          expect(access_control.read?(nil)).to be_truthy
        end
      end

      context 'non admin users' do
        context 'when the user has sufficient scope and permission' do
          let(:token) { { 'scope' => ['cloud_controller.read'] } }

          it 'allows the user to read' do
            allow(AppModel).to receive(:user_visible).and_return(AppModel.where(guid: app_model.guid))
            access_control = AppModelAccess.new(access_context)
            expect(access_control.read?(app_model)).to be_truthy
          end
        end

        context 'when the user has insufficient scope' do
          it 'disallows the user from reading' do
            allow(AppModel).to receive(:user_visible).and_return(AppModel.where(guid: app_model.guid))
            access_control = AppModelAccess.new(access_context)
            expect(access_control.read?(app_model)).to be_falsey
          end
        end

        context 'when the app is not visible to the user' do
          let(:token) { { 'scope' => ['cloud_controller.read'] } }

          it 'disallows the user from reading' do
            allow(AppModel).to receive(:user_visible).and_return(AppModel.where(guid: nil))
            access_control = AppModelAccess.new(access_context)
            expect(access_control.read?(app_model)).to be_falsey
          end
        end
      end
    end
  end
end
