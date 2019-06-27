require 'spec_helper'
require 'vcap/vars_builder'

module VCAP::CloudController
  RSpec.describe 'VarsBuilder' do
    describe 'vcap_application' do
      let(:v3_app_model) { AppModel.make(name: 'v3-app-name', space: space) }
      let(:process) { ProcessModelFactory.make(app: v3_app_model, memory: 259, disk_quota: 799, file_descriptors: 1234) }
      let(:space) { VCAP::CloudController::Space.make }

      describe 'building hash for a v2 app model (ProcessModel)' do
        it 'has the expected values' do
          v3_app_model.add_process(process)
          expected_hash = {
            cf_api: "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
            limits: {
              mem: process.memory,
              disk: process.disk_quota,
              fds: process.file_descriptors,
            },
            application_id: v3_app_model.guid,
            application_version: process.version,
            application_name: v3_app_model.name,
            application_uris: process.uris,
            version: process.version,
            name: process.name,
            space_name: process.space.name,
            space_id: process.space.guid,
            organization_id: process.organization.guid,
            organization_name: process.organization.name,
            process_id: process.guid,
            process_type: process.type,
            uris: process.uris,
            users: nil
          }

          vars_builder = VCAP::VarsBuilder.new(process)
          expect(vars_builder.to_hash).to eq(expected_hash)
        end
      end

      describe 'building hash for a v3 app model (AppModel)' do
        describe 'optional memory_limit, staging_disk_in_mb, file_descriptors and version' do
          context 'when memory_limit, staging_disk_in_mb, file_descriptors and version are supplied' do
            it 'builds hash with suppplied value' do
              expected_hash = {
                cf_api: "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
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
                organization_id: v3_app_model.organization.guid,
                organization_name: v3_app_model.organization.name,
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
                cf_api: "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
                limits: {},
                application_id: v3_app_model.guid,
                application_name: 'v3-app-name',
                application_uris: [],
                name: 'v3-app-name',
                space_name: v3_app_model.space.name,
                space_id: v3_app_model.space.guid,
                organization_id: v3_app_model.organization.guid,
                organization_name: v3_app_model.organization.name,
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
          it 'builds hash with supplied value' do
            expected_hash = {
              cf_api: "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
              limits: {
                mem: process.memory,
                disk: process.disk_quota,
                fds: process.file_descriptors,
              },
              application_id: process.guid,
              application_version: process.version,
              application_name: v3_app_model.name,
              application_uris: process.uris,
              version: process.version,
              name: v3_app_model.name,
              space_name: space.name,
              space_id: space.guid,
              organization_id: process.organization.guid,
              organization_name: process.organization.name,
              process_id: process.guid,
              process_type: process.type,
              uris: process.uris,
              users: nil
            }

            vars_builder = VCAP::VarsBuilder.new(
              process,
              space: space
            )
            expect(vars_builder.to_hash).to eq(expected_hash)
          end
        end

        context 'when no space is supplied' do
          it "defaults to app's space" do
            expected_hash = {
              cf_api: "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
              limits: {
                mem: process.memory,
                disk: process.disk_quota,
                fds: process.file_descriptors,
              },
              application_id: process.guid,
              application_version: process.version,
              application_name: v3_app_model.name,
              application_uris: process.uris,
              version: process.version,
              name: v3_app_model.name,
              space_name: process.space.name,
              space_id: process.space.guid,
              organization_id: process.organization.guid,
              organization_name: process.organization.name,
              process_id: process.guid,
              process_type: process.type,
              uris: process.uris,
              users: nil
            }

            vars_builder = VCAP::VarsBuilder.new(process)
            expect(vars_builder.to_hash).to eq(expected_hash)
          end
        end
      end
    end
  end
end
