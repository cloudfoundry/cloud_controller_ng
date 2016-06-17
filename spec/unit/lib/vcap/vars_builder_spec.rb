require 'spec_helper'
require 'vcap/vars_builder'

module VCAP::CloudController
  RSpec.describe 'VarsBuilder' do
    describe 'vcap_application' do
      let(:v3_app_model) { AppModel.make(name: 'v3-app-name') }
      let(:v2_app) { AppFactory.make(memory: 259, disk_quota: 799, file_descriptors: 1234, name: 'v2-app-name') }
      let(:space) { VCAP::CloudController::Space.make }

      describe 'building hash for a v2 app model' do
        context 'when a v3 app is associated' do
          it 'has the expected values' do
            process = AppFactory.make(memory: 259, disk_quota: 799, file_descriptors: 1234, name: 'process-name')
            v3_app_model.add_process(process)
            expected_hash = {
              limits: {
                mem: v2_app.memory,
                disk: v2_app.disk_quota,
                fds: v2_app.file_descriptors,
              },
              application_id: process.guid,
              application_version: process.version,
              application_name: v3_app_model.name,
              application_uris: process.uris,
              version: process.version,
              name: process.name,
              space_name: process.space.name,
              space_id: process.space.guid,
              uris: process.uris,
              users: nil
            }

            vars_builder = VCAP::VarsBuilder.new(process)
            expect(vars_builder.to_hash).to eq(expected_hash)
          end
        end

        context 'when a v3 app is not associated' do
          it 'has the expected values' do
            expected_hash = {
              limits: {
                mem: v2_app.memory,
                disk: v2_app.disk_quota,
                fds: v2_app.file_descriptors,
              },
              application_id: v2_app.guid,
              application_version: v2_app.version,
              application_name: 'v2-app-name',
              application_uris: v2_app.uris,
              version: v2_app.version,
              name: 'v2-app-name',
              space_name: v2_app.space.name,
              space_id: v2_app.space.guid,
              uris: v2_app.uris,
              users: nil
            }

            vars_builder = VCAP::VarsBuilder.new(v2_app)
            expect(vars_builder.to_hash).to eq(expected_hash)
          end
        end
      end

      describe 'building has for a v3 AppModel' do
        describe 'optional memory_limit, staging_disk_in_mb, file_descriptors and version' do
          context 'when memory_limit, staging_disk_in_mb, file_descriptors and version are supplied' do
            it 'builds hash with suppplied value' do
              expected_hash = {
                limits: {
                  mem: 1234,
                  disk: 5555,
                  fds: 8888,
                },
                application_id: v3_app_model.guid,
                application_name: 'v3-app-name',
                application_version: 'some-version',
                version: 'some-version',
                application_uris: [],
                name: 'v3-app-name',
                space_name: v3_app_model.space.name,
                space_id: v3_app_model.space.guid,
                uris: [],
                users: nil
              }

              vars_builder = VCAP::VarsBuilder.new(
                v3_app_model,
                memory_limit: 1234,
                staging_disk_in_mb: 5555,
                file_descriptors: 8888,
                version: 'some-version'
              )
              expect(vars_builder.to_hash).to eq(expected_hash)
            end
          end

          context 'no values are supplied' do
            it 'omits the fields in the hash' do
              expected_hash = {
                limits: {},
                application_id: v3_app_model.guid,
                application_name: 'v3-app-name',
                application_uris: [],
                name: 'v3-app-name',
                space_name: v3_app_model.space.name,
                space_id: v3_app_model.space.guid,
                uris: [],
                users: nil
              }

              vars_builder = VCAP::VarsBuilder.new(v3_app_model)
              expect(vars_builder.to_hash).to eq(expected_hash)
            end
          end
        end
      end

      describe 'optional space argument' do
        context 'when space is supplied' do
          it 'builds hash with suppplied value' do
            expected_hash = {
              limits: {
                mem: v2_app.memory,
                disk: v2_app.disk_quota,
                fds: v2_app.file_descriptors,
              },
              application_id: v2_app.guid,
              application_version: v2_app.version,
              application_name: 'v2-app-name',
              application_uris: v2_app.uris,
              version: v2_app.version,
              name: 'v2-app-name',
              space_name: space.name,
              space_id: space.guid,
              uris: v2_app.uris,
              users: nil
            }

            vars_builder = VCAP::VarsBuilder.new(
              v2_app,
              space: space
            )
            expect(vars_builder.to_hash).to eq(expected_hash)
          end
        end

        context 'when no space is supplied' do
          it "defaults to app's space" do
            expected_hash = {
              limits: {
                mem: v2_app.memory,
                disk: v2_app.disk_quota,
                fds: v2_app.file_descriptors,
              },
              application_id: v2_app.guid,
              application_version: v2_app.version,
              application_name: 'v2-app-name',
              application_uris: v2_app.uris,
              version: v2_app.version,
              name: 'v2-app-name',
              space_name: v2_app.space.name,
              space_id: v2_app.space.guid,
              uris: v2_app.uris,
              users: nil
            }

            vars_builder = VCAP::VarsBuilder.new(v2_app)
            expect(vars_builder.to_hash).to eq(expected_hash)
          end
        end
      end
    end
  end
end
