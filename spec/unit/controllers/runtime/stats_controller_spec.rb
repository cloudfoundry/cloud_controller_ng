require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::StatsController do
    let(:user) { make_user_for_space(process.space) }
    let(:developer) { make_developer_for_space(process.space) }
    let(:auditor) { make_auditor_for_space(process.space) }
    let(:process) { ProcessModelFactory.make }

    describe 'GET /v2/apps/:id/stats' do
      context 'when the client can see stats' do
        let(:stats) do
          {
            0 => {
              state: 'RUNNING',
              stats: {}
            },
            1 => {
              state: 'DOWN',
              details: 'start-me',
              since: 1
            }
          }
        end
        let(:warnings) { [] }
        let(:instances_reporters) { double(:instances_reporters) }

        before do
          CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
          allow(instances_reporters).to receive(:stats_for_app).and_return([stats, warnings])
        end

        context 'because they are a developer' do
          it 'returns the stats' do
            set_current_user(developer)

            process.state     = 'STARTED'
            process.instances = 1
            process.save

            process.refresh

            expected = {
              '0' => {
                'state' => 'RUNNING',
                'stats' => {}
              },
              '1' => {
                'state' => 'DOWN',
                'details' => 'start-me',
                'since' => 1
              }
            }

            get "/v2/apps/#{process.app.guid}/stats"

            expect(last_response.status).to eq(200)
            expect(MultiJson.load(last_response.body)).to eq(expected)
            expect(last_response.headers['X-Cf-Warnings']).to be_nil
            expect(instances_reporters).to have_received(:stats_for_app).with(
              satisfy { |requested_app| requested_app.guid == process.app.guid }
            )
          end
        end

        context 'because they are an auditor' do
          it 'returns the stats' do
            set_current_user(auditor)

            process.state     = 'STARTED'
            process.instances = 1
            process.save

            process.refresh

            expected = {
              '0' => {
                'state' => 'RUNNING',
                'stats' => {}
              },
              '1' => {
                'state' => 'DOWN',
                'details' => 'start-me',
                'since' => 1
              }
            }

            get "/v2/apps/#{process.app.guid}/stats"

            expect(last_response.status).to eq(200)
            expect(MultiJson.load(last_response.body)).to eq(expected)
            expect(instances_reporters).to have_received(:stats_for_app).with(
              satisfy { |requested_app| requested_app.guid == process.app.guid }
            )
          end
        end

        context 'when the instances reporter returns warnings' do
          let(:warnings) { %w[s0mjgnbha full_moon_with_s0mjgnbha] }

          it 'returns the stats with an X-Cf-Warnings header' do
            set_current_user(developer)

            process.state     = 'STARTED'
            process.instances = 1
            process.save

            process.refresh

            expected = {
              '0' => {
                'state' => 'RUNNING',
                'stats' => {}
              },
              '1' => {
                'state' => 'DOWN',
                'details' => 'start-me',
                'since' => 1
              }
            }

            get "/v2/apps/#{process.app.guid}/stats"

            expect(last_response.status).to eq(200)
            expect(MultiJson.load(last_response.body)).to eq(expected)
            expect(last_response.headers['X-Cf-Warnings']).to eq('s0mjgnbha,full_moon_with_s0mjgnbha')
            expect(instances_reporters).to have_received(:stats_for_app).with(
              satisfy { |requested_app| requested_app.guid == process.app.guid }
            )
          end
        end

        context 'when instance reporter raises an ApiError' do
          before do
            @error = CloudController::Errors::ApiError.new_from_details('ServerError')
            allow(instances_reporters).to receive(:stats_for_app).and_raise(@error)
            set_current_user(developer)
          end

          it 'does not re-raise as a StatsError' do
            process.update(state: 'STARTED')
            expect do
              get "/v2/apps/#{process.app.guid}/stats"
            end.to raise_error(@error)
          end
        end

        context 'when there is an error finding instances' do
          before do
            allow(instances_reporters).to receive(:stats_for_app).and_raise(CloudController::Errors::ApiError.new_from_details('StatsError', 'msg'))
            set_current_user(developer)
          end

          it 'raises an error' do
            process.update(state: 'STARTED')

            get "/v2/apps/#{process.app.guid}/stats"

            expect(last_response.status).to eq(400)
            expect(MultiJson.load(last_response.body)['code']).to eq(200_001)
          end
        end

        context 'when the app is stopped' do
          before do
            set_current_user(developer)
            process.update(state: 'STOPPED')
          end

          it 'raises an error' do
            get "/v2/apps/#{process.app.guid}/stats"

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match("Could not fetch stats for stopped app: #{process.name}")
          end
        end

        context 'when the app is a diego app' do
          let(:stats) do
            {
              '0' => {
                state: 'RUNNING',
                stats: {
                  name: 'foo',
                  uris: 'some-uris',
                  host: 'my-host',
                  port: 1234,
                  net_info: { 'foo' => 'bar' },
                  uptime: 1,
                  mem_quota: 1,
                  disk_quota: 2,
                  fds_quota: 3,
                  usage: {
                    time: 4,
                    cpu: 5,
                    mem: 6,
                    disk: 7
                  }
                }
              }
            }
          end

          describe 'isolation segments' do
            let(:stats) do
              {
                '0' => {
                  state: 'RUNNING',
                  isolation_segment: 'isolation-segment-name',
                  stats: {
                    name: 'foo',
                    uris: 'some-uris',
                    host: 'my-host',
                    port: 1234,
                    net_info: { 'foo' => 'bar' },
                    uptime: 1,
                    mem_quota: 1,
                    disk_quota: 2,
                    fds_quota: 3,
                    usage: {
                      time: 4,
                      cpu: 5,
                      mem: 6,
                      disk: 7
                    }
                  }
                }
              }
            end

            it 'includes the isolation segment name for the app' do
              set_current_user(developer)

              process.state = 'STARTED'
              process.instances = 1
              process.save

              process.refresh

              get "/v2/apps/#{process.app.guid}/stats"

              expect(last_response.status).to eq(200)
              expect(MultiJson.load(last_response.body)['0']['isolation_segment']).to eq('isolation-segment-name')
            end
          end

          it 'returns the stats without the net_info field' do
            set_current_user(developer)

            process.state     = 'STARTED'
            process.instances = 1
            process.save

            process.refresh

            expected = {
              '0' => {
                'state' => 'RUNNING',
                'stats' => {
                  'name' => 'foo',
                  'uris' => 'some-uris',
                  'host' => 'my-host',
                  'port' => 1234,
                  'uptime' => 1,
                  'mem_quota' => 1,
                  'disk_quota' => 2,
                  'fds_quota' => 3,
                  'usage' => {
                    'time' => 4,
                    'cpu' => 5,
                    'mem' => 6,
                    'disk' => 7
                  }
                }
              }
            }

            get "/v2/apps/#{process.app.guid}/stats"

            expect(last_response.status).to eq(200)
            expect(MultiJson.load(last_response.body)).to eq(expected)
            expect(instances_reporters).to have_received(:stats_for_app).with(
              satisfy { |requested_app| requested_app.guid == process.app.guid }
            )
          end
        end
      end

      context 'when the client cannot see stats' do
        context 'because they are a user' do
          it 'returns 403' do
            set_current_user(user)

            get "/v2/apps/#{process.app.guid}/stats"

            expect(last_response.status).to eq(403)
          end
        end
      end
    end
  end
end
