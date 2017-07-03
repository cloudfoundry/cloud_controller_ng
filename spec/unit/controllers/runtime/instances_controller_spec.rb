require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::InstancesController do
    let(:instances_reporters) { double(:instances_reporters) }
    let(:index_stopper) { double(:index_stopper) }

    before do
      CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
      CloudController::DependencyLocator.instance.register(:index_stopper, index_stopper)
    end

    describe 'GET /v2/apps/:id/instances' do
      before :each do
        @process = AppFactory.make
        @user      = make_user_for_space(@process.space)
        @developer = make_developer_for_space(@process.space)
        set_current_user(user)
      end

      context 'as a developer' do
        let(:user) { @developer }

        it 'returns 400 when there is an error finding the instances' do
          @process.state = 'STOPPED'
          @process.save

          get "/v2/apps/#{@process.guid}/instances"

          expect(last_response.status).to eq(400)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['code']).to eq(220001)
          expect(parsed_response['description']).to eq("Instances error: Request failed for app: #{@process.name} as the app is in stopped state.")
        end

        it "returns '170001 StagingError' when the app is failed to stage" do
          @process.latest_build.update(state: BuildModel::FAILED_STATE)
          @process.reload

          get "/v2/apps/#{@process.guid}/instances"

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170001)
        end

        it "returns '170002 NotStaged' when the app is pending to be staged" do
          @process.current_droplet.destroy
          @process.reload

          get "/v2/apps/#{@process.guid}/instances"

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170002)
        end

        it "returns '170003 NoAppDetectedError' when the app was not detected by a buildpack" do
          build = @process.latest_build.update(state: BuildModel::FAILED_STATE)
          @process.latest_droplet.update(state: DropletModel::FAILED_STATE, build: build, error_id: 'NoAppDetectedError')
          @process.reload

          get "/v2/apps/#{@process.guid}/instances"

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170003)
        end

        it "returns '170004 BuildpackCompileFailed' when the app fails due in the buildpack compile phase" do
          build = @process.latest_build.update(state: BuildModel::FAILED_STATE)
          @process.latest_droplet.update(state: DropletModel::FAILED_STATE, build: build, error_id: 'BuildpackCompileFailed')
          @process.reload

          get "/v2/apps/#{@process.guid}/instances"

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170004)
        end

        it "returns '170005 BuildpackReleaseFailed' when the app fails due in the buildpack compile phase" do
          build = @process.latest_build.update(state: BuildModel::FAILED_STATE)
          @process.latest_droplet.update(state: DropletModel::FAILED_STATE, build: build, error_id: 'BuildpackReleaseFailed')
          @process.reload

          get "/v2/apps/#{@process.guid}/instances"

          expect(last_response.status).to eq(400)
          expect(MultiJson.load(last_response.body)['code']).to eq(170005)
        end

        context 'when the app is started' do
          before do
            @process.state     = 'STARTED'
            @process.instances = 1
            @process.save

            @process.refresh
          end

          it 'returns the instances' do
            instances = {
              0 => {
                state:   'FLAPPING',
                details: 'busted-app',
                since:   1,
              },
            }

            expected = {
              '0' => {
                'state'   => 'FLAPPING',
                'details' => 'busted-app',
                'since'   => 1,
              },
            }

            allow(instances_reporters).to receive(:all_instances_for_app).and_return(instances)

            get "/v2/apps/#{@process.guid}/instances"

            expect(last_response.status).to eq(200)
            expect(MultiJson.load(last_response.body)).to eq(expected)
            expect(instances_reporters).to have_received(:all_instances_for_app).with(
              satisfy { |requested_app| requested_app.guid == @process.guid })
          end
        end
      end

      context 'as a non-developer' do
        let(:user) { @user }
        it 'returns 403' do
          get "/v2/apps/#{@process.guid}/instances"
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'DELETE /v2/apps/:id/instances/:index' do
      let(:process) { AppFactory.make(state: 'STARTED', instances: 2) }

      before { set_current_user(user) }

      context 'as a developer or space manager' do
        let(:user) { make_developer_for_space(process.space) }

        it 'stops the instance at the given index' do
          allow(index_stopper).to receive(:stop_index)

          delete "/v2/apps/#{process.guid}/instances/1"

          expect(last_response.status).to eq(204)
          expect(index_stopper).to have_received(:stop_index).with(process, 1)
        end
      end

      context 'as a non-developer' do
        let(:user) { make_user_for_space(process.space) }

        it 'returns 403' do
          delete "/v2/apps/#{process.guid}/instances/1"
          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
