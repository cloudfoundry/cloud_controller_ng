require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::StatsController do
    describe 'GET /v2/apps/:id/stats' do
      before :each do
        @app = AppFactory.make(package_hash: 'abc', package_state: 'STAGED')
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
        @auditor = make_auditor_for_space(@app.space)
      end

      context 'when the client can see stats' do
        let(:stats) do
          {
            0 => {
              state: 'RUNNING',
              stats: 'mock stats',
            },
            1 => {
              state: 'DOWN',
              details: 'start-me',
              since: 1,
            }
          }
        end
        let(:instances_reporters) { double(:instances_reporters) }

        before do
          CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
          allow(instances_reporters).to receive(:stats_for_app).and_return(stats)
        end

        context 'because they are a developer' do
          it 'should return the stats' do
            @app.state = 'STARTED'
            @app.instances = 1
            @app.save

            @app.refresh

            expected = {
              '0' => {
                'state' => 'RUNNING',
                'stats' => 'mock stats',
              },
              '1' => {
                'state' => 'DOWN',
                'details' => 'start-me',
                'since' => 1,
              }
            }

            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@developer))

            expect(last_response.status).to eq(200)
            expect(MultiJson.load(last_response.body)).to eq(expected)
            expect(instances_reporters).to have_received(:stats_for_app).with(
                                            satisfy { |requested_app| requested_app.guid == @app.guid })
          end
        end

        context 'because they are an auditor' do
          it 'should return the stats' do
            @app.state = 'STARTED'
            @app.instances = 1
            @app.save

            @app.refresh

            expected = {
              '0' => {
                'state' => 'RUNNING',
                'stats' => 'mock stats',
              },
              '1' => {
                'state' => 'DOWN',
                'details' => 'start-me',
                'since' => 1,
              }
            }

            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@auditor))

            expect(last_response.status).to eq(200)
            expect(MultiJson.load(last_response.body)).to eq(expected)
            expect(instances_reporters).to have_received(:stats_for_app).with(
                                            satisfy { |requested_app| requested_app.guid == @app.guid })
          end
        end

        context 'when instance reporter is unavailable' do
          before do
            allow(instances_reporters).to receive(:stats_for_app).and_raise(VCAP::Errors::InstancesUnavailable.new(StandardError.new))
          end

          it 'returns 503' do
            @app.update(state: 'STARTED')

            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@developer))

            expect(last_response.status).to eq(503)
            expect(last_response.body).to match('Stats unavailable: Stats server temporarily unavailable.')
          end
        end

        context 'when there is an error finding instances' do
          before do
            allow(instances_reporters).to receive(:stats_for_app).and_raise(VCAP::Errors::ApiError.new_from_details('StatsError', 'msg'))
          end

          it 'raises an error' do
            @app.update(state: 'STARTED')

            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@developer))

            expect(last_response.status).to eq(400)
            expect(MultiJson.load(last_response.body)['code']).to eq(200001)
          end
        end

        context 'when the app is stopped' do
          before do
            @app.stop!
          end

          it 'raises an error' do
            get("/v2/apps/#{@app.guid}/stats", {}, headers_for(@developer))

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match("Could not fetch stats for stopped app: #{@app.name}")
          end
        end
      end

      context 'when the client cannot see stats' do
        context 'because they are a user' do
          it 'should return 403' do
            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@user))

            expect(last_response.status).to eq(403)
          end
        end
      end
    end
  end
end
