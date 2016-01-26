require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::InstancesController do
    let(:instances_reporters) { double(:instances_reporters) }
    let(:index_stopper) { double(:index_stopper) }

    before do
      CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
      CloudController::DependencyLocator.instance.register(:index_stopper, index_stopper)
    end

    describe 'GET /v2/apps/:id/instances' do
      before :each do
        @app = AppFactory.make(package_hash: 'abc', package_state: 'STAGED')
        @user = make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      context 'as a developer' do
        let(:user) { @developer }

        it 'returns 400 when there is an error finding the instances' do
          @app.state = 'STOPPED'
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['code']).to eq(220001)
          expect(parsed_response['description']).to eq("Instances error: Request failed for app: #{@app.name} as the app is in stopped state.")
        end

        it "returns '170001 StagingError' when the app is failed to stage" do
          @app.package_state = 'FAILED'
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170001)
        end

        it "returns '170002 NotStaged' when the app is pending to be staged" do
          @app.package_state = 'PENDING'
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170002)
        end

        it "returns '170003 NoAppDetectedError' when the app was not detected by a buildpack" do
          @app.mark_as_failed_to_stage('NoAppDetectedError')
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170003)
        end

        it "returns '170004 BuildpackCompileFailed' when the app fails due in the buildpack compile phase" do
          @app.mark_as_failed_to_stage('BuildpackCompileFailed')
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170004)
        end

        it "returns '170005 BuildpackReleaseFailed' when the app fails due in the buildpack compile phase" do
          @app.mark_as_failed_to_stage('BuildpackReleaseFailed')
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170005)
        end

        context 'when the app is started' do
          before do
            @app.state = 'STARTED'
            @app.instances = 1
            @app.save

            @app.refresh
          end

          it 'returns the instances' do
            instances = {
              0 => {
                state: 'FLAPPING',
                details: 'busted-app',
                since: 1,
              },
            }

            expected = {
              '0' => {
                'state' => 'FLAPPING',
                'details' => 'busted-app',
                'since' => 1,
              },
            }

            allow(instances_reporters).to receive(:all_instances_for_app).and_return(instances)

            get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

            expect(last_response.status).to eq(200)
            expect(MultiJson.load(last_response.body)).to eq(expected)
            expect(instances_reporters).to have_received(:all_instances_for_app).with(
              satisfy { |requested_app| requested_app.guid == @app.guid })
          end

          context 'when the instances reporter fails' do
            class SomeInstancesException < RuntimeError
              def to_s
                "It's the end of the world as we know it."
              end
            end

            before do
              allow(instances_reporters).to receive(:all_instances_for_app).and_raise(
                Errors::InstancesUnavailable.new(SomeInstancesException.new))
            end

            it "returns '220001 InstancesError'" do
              get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))

              expect(last_response.status).to eq(503)

              parsed_response = MultiJson.load(last_response.body)
              expect(parsed_response['code']).to eq(220002)
              expect(parsed_response['description']).to eq("Instances information unavailable: It's the end of the world as we know it.")
            end
          end
        end
      end

      context 'as a non-developer' do
        let(:user) { @user }
        it 'returns 403' do
          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(user))
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'DELETE /v2/apps/:id/instances/:index' do
      let(:app_obj) { AppFactory.make(state: 'STARTED', instances: 2) }

      context 'as a developer or space manager' do
        let(:user) { make_developer_for_space(app_obj.space) }

        it 'stops the instance at the given index' do
          allow(index_stopper).to receive(:stop_index)

          delete "/v2/apps/#{app_obj.guid}/instances/1", '', headers_for(user)

          expect(last_response.status).to eq(204)
          expect(index_stopper).to have_received(:stop_index).with(app_obj, 1)
        end
      end

      context 'as a non-developer' do
        let(:user) { make_user_for_space(app_obj.space) }

        it 'returns 403' do
          delete "/v2/apps/#{app_obj.guid}/instances/1", '', headers_for(user)
          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
