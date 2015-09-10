require 'spec_helper'
require 'securerandom'

describe 'Staging an app', type: :integration do
  before do
    start_nats(debug: false)
    start_cc(debug: false, config: 'spec/fixtures/config/port_8181_config.yml')
    @tmpdir = Dir.mktmpdir
  end

  after do
    stop_cc
    stop_nats
  end

  context 'when admin buildpacks are used' do
    let(:stager_id) { 'abc123' }
    let(:advertisment) do
      {
        'id' => stager_id,
        'stacks' => ['cflinuxfs2'],
        'available_memory' => 2048,
      }.to_json
    end

    let(:authed_headers) do
      {
        'Authorization' => "bearer #{admin_token}",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    end

    def valid_zip(size=1)
      @valid_zip ||= {}
      @valid_zip[size.to_s] ||= begin
        zip_name = File.join(@tmpdir, "file_#{size}.zip")
        TestZip.create(zip_name, size, 1024)
        File.new(zip_name)
      end
    end

    before do
      @buildpack_response_1 = make_post_request(
        '/v2/buildpacks',
        { 'name' => 'buildpack-1', 'position' => 2 }.to_json,
        authed_headers
      )

      @buildpack_response_2 = make_post_request(
        '/v2/buildpacks',
        { 'name' => 'buildpack-2', 'position' => 1 }.to_json,
        authed_headers
      )

      @expected_buildpack_shas = [
        "#{@buildpack_response_2.json_body['metadata']['guid']}_#{Digester.new.digest_path(valid_zip)}",
        "#{@buildpack_response_1.json_body['metadata']['guid']}_#{Digester.new.digest_path(valid_zip(4))}",
      ]

      org = make_post_request(
        '/v2/organizations',
        { 'name' => "foo_org-#{SecureRandom.uuid}" }.to_json,
        authed_headers
      )
      space = make_post_request(
        '/v2/spaces',
        {
          'name' => 'foo_space',
          'organization_guid' => org.json_body['metadata']['guid']
        }.to_json,
        authed_headers
      )

      @app_response = make_post_request(
        '/v2/apps',
        {
          'name' => 'foobar',
          'memory' => 64,
          'instances' => 2,
          'disk_quota' => 1024,
          'space_guid' => space.json_body['metadata']['guid'],
        }.to_json,
        authed_headers
      )

      @app_bits_response = make_put_request(
        "/v2/apps/#{@app_response.json_body['metadata']['guid']}/bits?application[tempfile]=#{valid_zip(2).path}&resources=[]",
        '{}',
        authed_headers
      )
    end

    context 'and the admin has not uploaded yet the buildpacks' do
      context 'and an app is staged' do
        it 'does not include any buildpacks in the request' do
          expect(@buildpack_response_1.code).to eq('201')
          expect(@buildpack_response_2.code).to eq('201')
          expect(@app_response.code).to eq('201')
          expect(@app_bits_response.code).to eq('201')

          NATS.start do
            NATS.subscribe "staging.#{stager_id}.start", queue: 'staging' do |msg|
              expect(JSON.parse(msg)['admin_buildpacks']).to be_empty

              app_stop_response = make_put_request(
                "/v2/apps/#{@app_response.json_body['metadata']['guid']}",
                { state: 'STOPPED' }.to_json,
                authed_headers
              )

              expect(app_stop_response.code).to eq('201')

              NATS.stop
            end

            NATS.publish('dea.advertise', advertisment) do
              NATS.publish('staging.advertise', advertisment) do
                Thread.new do
                  app_start_response = make_put_request(
                    "/v2/apps/#{@app_response.json_body['metadata']['guid']}",
                    { state: 'STARTED' }.to_json,
                    authed_headers
                  )

                  expect(app_start_response.code).to eq('201')
                end
              end
            end
          end
        end
      end
    end

    context 'and the admin has uploaded the buildpacks' do
      before do
        @buildpack_bits_response_1 = make_put_request(
          "/v2/buildpacks/#{@buildpack_response_1.json_body['metadata']['guid']}/bits?buildpack[tempfile]=#{valid_zip(4).path}&buildpack_name=foo.zip",
          '{}',
          authed_headers
        )

        @buildpack_bits_response_2 = make_put_request(
          "/v2/buildpacks/#{@buildpack_response_2.json_body['metadata']['guid']}/bits?buildpack[tempfile]=#{valid_zip.path}&buildpack_name=bar.zip",
          '{}',
          authed_headers
        )
      end

      context 'and an app is staged' do
        it 'includes the buildpacks in the correct order' do
          stager_id = 'abc123'
          expect(@buildpack_response_1.code).to eq('201')
          expect(@buildpack_response_2.code).to eq('201')
          expect(@buildpack_bits_response_1.code).to eq('201')
          expect(@buildpack_bits_response_2.code).to eq('201')

          NATS.start do
            NATS.subscribe "staging.#{stager_id}.start", queue: 'staging' do |msg|
              json_message = JSON.parse(msg)
              expect(json_message['admin_buildpacks'].map { |bp| bp['key'] }).to eq(@expected_buildpack_shas)

              NATS.stop
            end

            NATS.publish('dea.advertise', advertisment) do
              NATS.publish('staging.advertise', advertisment) do
                Thread.new do
                  app_start_response = make_put_request(
                    "/v2/apps/#{@app_response.json_body['metadata']['guid']}",
                    { state: 'STARTED' }.to_json,
                    authed_headers
                  )

                  expect(app_start_response.code).to eq('201')
                end
              end
            end
          end
        end

        context 'excludes disabled buildpacks' do
          before do
            @enabled_buildpack_shas = @expected_buildpack_shas[1..1]
            @buildpack_response_2_disable = make_put_request(
              "/v2/buildpacks/#{@buildpack_response_2.json_body['metadata']['guid']}",
              { 'enabled' => false }.to_json,
              authed_headers
            )
          end

          it 'includes enabled buildpacks' do
            stager_id = 'abc123'
            expect(@buildpack_response_1.code).to eq('201')
            expect(@buildpack_response_2.code).to eq('201')
            expect(@buildpack_bits_response_1.code).to eq('201')
            expect(@buildpack_bits_response_2.code).to eq('201')
            expect(@buildpack_response_2_disable.code).to eq('201')

            NATS.start do
              NATS.subscribe "staging.#{stager_id}.start", queue: 'staging' do |msg|
                json_message = JSON.parse(msg)
                expect(json_message['admin_buildpacks'].map { |bp| bp['key'] }).to eq(@enabled_buildpack_shas)

                NATS.stop
              end

              NATS.publish('dea.advertise', advertisment) do
                NATS.publish('staging.advertise', advertisment) do
                  Thread.new do
                    app_start_response = make_put_request(
                      "/v2/apps/#{@app_response.json_body['metadata']['guid']}",
                      { state: 'STARTED' }.to_json,
                      authed_headers
                    )

                    expect(app_start_response.code).to eq('201')
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
