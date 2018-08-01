require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::FilesController do
    describe 'GET /v2/apps/:id/instances/:instance/files/(:path)' do
      before :each do
        @app = AppFactory.make
        @user = make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      before :each, use_nginx: false do
        TestConfig.override(nginx: { use_nginx: false })
      end

      context 'as a developer' do
        before { set_current_user(@developer) }

        it 'returns 400 when a bad instance is used' do
          get "/v2/apps/#{@app.guid}/instances/kows$ik/files"

          expect(last_response.status).to eq(400)

          get "/v2/apps/#{@app.guid}/instances/-1/files"

          expect(last_response.status).to eq(400)
        end

        it 'returns 400 when there is an error finding the instance' do
          instance = 5

          @app.state = 'STOPPED'
          @app.save

          get "/v2/apps/#{@app.guid}/instances/#{instance}/files"

          expect(last_response.status).to eq(400)
        end

        it 'issues redirect', use_nginx: false do
          instance = 5
          range = 'bytes=100-200'

          @app.state = 'STARTED'
          @app.instances = 10
          @app.save
          @app.refresh

          to_return = Dea::FileUriResult.new(
            file_uri_v1: 'file_uri/',
            credentials: [],
            file_uri_v2: 'file_uri/',
          )
          expect(Dea::Client).to receive(:get_file_uri_for_active_instance_by_index).
            with(@app, nil, 5).and_return(to_return)

          get "/v2/apps/#{@app.guid}/instances/#{instance}/files", nil, 'HTTP_RANGE' => range

          expect(last_response.status).to eq(302)
          expect(last_response.headers).to include('Location' => 'file_uri/')
        end
      end

      context 'as a user' do
        before { set_current_user(@user) }

        it 'returns 403' do
          get "/v2/apps/#{@app.guid}/instances/bad_instance/files"

          expect(last_response.status).to eq(403)

          @app.state = 'STARTED'
          @app.instances = 10
          @app.save

          get "/v2/apps/#{@app.guid}/instances/5/files"

          expect(last_response.status).to eq(403)

          get "/v2/apps/#{@app.guid}/instances/5/files/path"

          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
