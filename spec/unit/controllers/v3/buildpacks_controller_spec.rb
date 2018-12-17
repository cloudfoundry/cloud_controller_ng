require 'rails_helper'
require 'messages/buildpack_create_message'
require 'models/runtime/buildpack'

RSpec.describe BuildpacksController, type: :controller do
  describe '#create' do
    context 'when authorized' do
      let(:user) { VCAP::CloudController::User.make }
      let(:stack) { VCAP::CloudController::Stack.make }
      let(:params) do
        {
          name: 'the-r3al_Name',
          stack: stack.name,
          position: 2,
          enabled: false,
          locked: true,
        }
      end

      before do
        set_current_user_as_admin(user: user)
      end

      context 'when params are correct' do
        context 'when the stack exists' do
          let(:stack) { VCAP::CloudController::Stack.make }

          it 'should save the buildpack in the database' do
            post :create, params: params, as: :json

            our_buildpack = VCAP::CloudController::Buildpack.last
            expect(our_buildpack).to_not be_nil
            expect(our_buildpack.name).to eq(params[:name])
            expect(our_buildpack.stack).to eq(params[:stack])
            expect(our_buildpack.position).to eq(params[:position])
            expect(our_buildpack.enabled).to eq(params[:enabled])
            expect(our_buildpack.locked).to eq(params[:locked])
          end
        end

        context 'when the stack does not exist' do
          let(:stack) { double(:stack, name: 'does-not-exist') }

          it 'does not create the buildpack' do
            expect { post :create, params: params, as: :json }.
              to_not change { VCAP::CloudController::Buildpack.count }
          end

          it 'returns 422' do
            post :create, params: params, as: :json

            expect(response.status).to eq 422
          end

          it 'returns a helpful error message' do
            post :create, params: params, as: :json

            expect(parsed_body['errors'][0]['detail']).to include("Stack \"#{stack.name}\" does not exist")
          end
        end
      end

      context 'when params are invalid' do
        before do
          allow_any_instance_of(VCAP::CloudController::BuildpackCreateMessage).
            to receive(:valid?).and_return(false)
        end

        it 'returns 422' do
          post :create, params: params, as: :json

          expect(response.status).to eq 422
        end

        it 'does not create the buildpack' do
          expect { post :create, params: params, as: :json }.
            to_not change { VCAP::CloudController::Buildpack.count }
        end
      end
    end
  end

  describe '#show' do
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
    end

    context 'when the buildpack exists' do
      let(:buildpack) { VCAP::CloudController::Buildpack.make }
      it 'renders a single buildpack details' do
        get :show, params: { guid: buildpack.guid }
        expect(response.status).to eq 200
        expect(parsed_body['guid']).to eq(buildpack.guid)
      end
    end

    context 'when the buildpack does not exist' do
      it 'errors' do
        get :show, params: { guid: 'psych!' }
        expect(response.status).to eq 404
        expect(response.body).to include('ResourceNotFound')
      end
    end
  end
end
