require 'spec_helper'
require 'actions/app_apply_manifest'

module VCAP::CloudController
  RSpec.describe AppApplyManifest, job_context: :worker do
    context 'when everything is mocked out' do
      subject(:app_apply_manifest) { AppApplyManifest.new(user_audit_info) }
      let(:user_audit_info) { instance_double(UserAuditInfo) }
      let(:process_scale) { instance_double(ProcessScale) }
      let(:route_mapping_delete) { instance_double(RouteMappingDelete) }
      let(:app_update) { instance_double(AppUpdate) }
      let(:app_patch_env) { instance_double(AppPatchEnvironmentVariables) }
      let(:process_update) { instance_double(ProcessUpdate) }
      let(:process_create) { instance_double(ProcessCreate) }
      let(:service_cred_binding_create) { instance_double(V3::ServiceCredentialBindingAppCreate) }
      let(:random_route_generator) { instance_double(RandomRouteGenerator, route: 'spiffy/donut') }

      describe '#apply' do
        before do
          allow(RandomRouteGenerator).to receive(:new).and_return(random_route_generator)

          allow(ProcessScale).
            to receive(:new).and_return(process_scale)
          allow(process_scale).to receive(:scale)

          allow(ProcessCreate).
            to receive(:new).and_return(process_create)
          allow(process_create).to receive(:create)

          allow(AppUpdate).
            to receive(:new).and_return(app_update)
          allow(app_update).to receive(:update)

          allow(ProcessUpdate).
            to receive(:new).and_return(process_update)
          allow(process_update).to receive(:update)

          allow(ManifestRouteUpdate).to receive(:update)

          allow(SidecarUpdate).to receive(:update)
          allow(SidecarCreate).to receive(:create)

          allow(RouteMappingDelete).
            to receive(:new).and_return(route_mapping_delete)
          allow(route_mapping_delete).to receive(:delete)

          allow(V3::ServiceCredentialBindingAppCreate).
            to receive(:new).and_return(service_cred_binding_create)
          allow(service_cred_binding_create).to receive(:precursor)
          allow(service_cred_binding_create).to receive(:bind)

          allow(AppPatchEnvironmentVariables).
            to receive(:new).and_return(app_patch_env)
          allow(app_patch_env).to receive(:patch)
        end

        describe 'scaling a process' do
          describe 'scaling instances' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', instances: 4 }) }
            let(:manifest_process_scale_message) { message.manifest_process_scale_messages.first }
            let(:process) { ProcessModel.make(instances: 1) }
            let(:app) { process.app }

            context 'when the request is valid' do
              it 'returns the app' do
                expect(
                  app_apply_manifest.apply(app.guid, message)
                ).to eq(app)
              end

              it 'calls ProcessScale with the correct arguments' do
                app_apply_manifest.apply(app.guid, message)
                expect(ProcessScale).to have_received(:new).with(user_audit_info, process, an_instance_of(ProcessScaleMessage), manifest_triggered: true)
                expect(process_scale).to have_received(:scale)
              end
            end
          end

          describe 'scaling memory' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', memory: '256MB' }) }
            let(:manifest_process_scale_message) { message.manifest_process_scale_messages.first }
            let(:process) { ProcessModel.make(memory: 512) }
            let(:app) { process.app }

            context 'when the request is valid' do
              it 'returns the app' do
                expect(
                  app_apply_manifest.apply(app.guid, message)
                ).to eq(app)
              end

              it 'calls ProcessScale with the correct arguments' do
                app_apply_manifest.apply(app.guid, message)
                expect(ProcessScale).to have_received(:new).with(user_audit_info, process, instance_of(ProcessScaleMessage), manifest_triggered: true)
                expect(process_scale).to have_received(:scale)
              end
            end
          end
        end

        describe 'updating buildpack' do
          let(:buildpack) { VCAP::CloudController::Buildpack.make }
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', buildpack: buildpack.name }) }
          let(:app_update_message) { message.app_update_message }
          let(:app) { AppModel.make }

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls AppUpdate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(AppUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(app_update).to have_received(:update).
                with(app, app_update_message, instance_of(AppBuildpackLifecycle))
            end

            describe 'using cnb type' do
              let(:app) { AppModel.make(:cnb) }

              it 'calls AppUpdate with the correct arguments' do
                app_apply_manifest.apply(app.guid, message)
                expect(AppUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
                expect(app_update).to have_received(:update).
                  with(app, app_update_message, instance_of(AppCNBLifecycle))
              end
            end
          end

          context 'when the request is invalid due to failure to update the app' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', buildpack: buildpack.name }) }

            before do
              allow(app_update).
                to receive(:update).and_raise(AppUpdate::InvalidApp.new('invalid app'))
            end

            it 'bubbles up the error' do
              expect do
                app_apply_manifest.apply(app.guid, message)
              end.to raise_error(AppUpdate::InvalidApp, 'invalid app')
            end
          end
        end

        describe 'updating stack' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'stack-test', stack: 'cflinuxfs4' }) }
          let(:app_update_message) { message.app_update_message }
          let(:app) { AppModel.make }

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls AppUpdate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(AppUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(app_update).to have_received(:update).
                with(app, app_update_message, instance_of(AppBuildpackLifecycle))
            end
          end

          context 'when the request is invalid' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'stack-test', stack: 'no-such-stack' }) }

            before do
              allow(app_update).
                to receive(:update).and_raise(AppUpdate::InvalidApp.new('invalid app'))
            end

            it 'bubbles up the error' do
              expect do
                app_apply_manifest.apply(app.guid, message)
              end.to raise_error(AppUpdate::InvalidApp, 'invalid app')
            end
          end
        end

        describe 'updating environment variables' do
          let(:message) { AppManifestMessage.create_from_yml({ env: { foo: 'bar' } }) }
          let(:app_update_environment_variables_message) { message.app_update_environment_variables_message }
          let(:app) { AppModel.make }

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls AppPatchEnvironmentVariables with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(AppPatchEnvironmentVariables).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(app_patch_env).to have_received(:patch).
                with(app, app_update_environment_variables_message)
            end
          end

          context 'when the request is invalid' do
            let(:message) { AppManifestMessage.create_from_yml({ env: 'not-a-hash' }) }

            before do
              allow(app_patch_env).
                to receive(:patch).and_raise(AppPatchEnvironmentVariables::InvalidApp.new('invalid app'))
            end

            it 'bubbles up the error' do
              expect do
                app_apply_manifest.apply(app.guid, message)
              end.to raise_error(AppPatchEnvironmentVariables::InvalidApp, 'invalid app')
            end
          end
        end

        describe 'updating command' do
          let(:message) { AppManifestMessage.create_from_yml({ command: 'new-command' }) }
          let(:manifest_process_update_message) { message.manifest_process_update_messages.first }
          let(:app) { AppModel.make }

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls ProcessUpdate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ProcessUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(process_update).to have_received(:update).
                with(app.web_processes.first, manifest_process_update_message, ManifestStrategy)
            end
          end

          context 'when the request is invalid' do
            let(:message) { AppManifestMessage.create_from_yml({ command: '' }) }

            before do
              allow(process_update).
                to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('invalid process'))
            end

            it 'bubbles up the error' do
              expect do
                app_apply_manifest.apply(app.guid, message)
              end.to raise_error(ProcessUpdate::InvalidProcess, 'invalid process')
            end
          end
        end

        describe 'updating multiple process attributes' do
          let(:message) do
            AppManifestMessage.create_from_yml({
                                                 processes: [
                                                   { type: 'web', command: 'web-command', instances: 2 },
                                                   { type: 'worker', command: 'worker-command', instances: 3 }
                                                 ]
                                               })
          end
          let!(:process1) { ProcessModel.make(type: 'web') }
          let!(:app) { process1.app }
          let!(:process2) { ProcessModel.make(app: app, type: 'worker') }
          let(:manifest_process_update_message1) { message.manifest_process_update_messages.first }
          let(:manifest_process_update_message2) { message.manifest_process_update_messages.last }

          let(:manifest_process_scale_message1) { message.manifest_process_scale_messages.first }
          let(:manifest_process_scale_message2) { message.manifest_process_scale_messages.last }

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls ProcessUpdate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ProcessUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true).exactly(2).times
              expect(process_update).to have_received(:update).with(process1, manifest_process_update_message1, ManifestStrategy)
              expect(process_update).to have_received(:update).with(process2, manifest_process_update_message2, ManifestStrategy)
            end

            it 'calls ProcessScale with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ProcessScale).to have_received(:new).with(user_audit_info, process1, instance_of(ProcessScaleMessage), manifest_triggered: true)
              expect(ProcessScale).to have_received(:new).with(user_audit_info, process2, instance_of(ProcessScaleMessage), manifest_triggered: true)
              expect(process_scale).to have_received(:scale).exactly(2).times
            end
          end

          context 'when the request is invalid' do
            let(:message) { AppManifestMessage.create_from_yml({ command: '' }) }

            before do
              allow(process_update).
                to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('invalid process'))
            end

            it 'bubbles up the error' do
              expect do
                app_apply_manifest.apply(app.guid, message)
              end.to raise_error(ProcessUpdate::InvalidProcess, 'invalid process')
            end
          end
        end

        describe 'creating a new process' do
          let(:message) do
            AppManifestMessage.create_from_yml({
                                                 processes: [
                                                   { type: 'potato', command: 'potato-command', instances: 3 }
                                                 ]
                                               })
          end

          let!(:app) { AppModel.make }
          let(:update_message) { message.manifest_process_update_messages.first }
          let(:scale_message) { message.manifest_process_scale_messages.first }

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls ProcessCreate with command and type' do
              app_apply_manifest.apply(app.guid, message)
              expect(ProcessCreate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(process_create).to have_received(:create).with(app, { type: 'potato', command: 'potato-command' })
            end

            it 'updates and scales the newly created process with all the other properties' do
              app_apply_manifest.apply(app.guid, message)
              expect(ProcessUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              process = ProcessModel.last
              expect(process_update).to have_received(:update).with(process, update_message, ManifestStrategy)

              expect(ProcessScale).to have_received(:new).with(user_audit_info, process, instance_of(ProcessScaleMessage), manifest_triggered: true)
              expect(process_scale).to have_received(:scale)
            end

            context 'when there is no command specified in the manifest' do
              let(:message) do
                AppManifestMessage.create_from_yml({
                                                     processes: [
                                                       { type: 'potato', instances: 3 }
                                                     ]
                                                   })
              end

              it 'sets the command to nil' do
                app_apply_manifest.apply(app.guid, message)
                expect(ProcessCreate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
                expect(process_create).to have_received(:create).with(app, { type: 'potato', command: nil })
              end
            end
          end
        end

        describe 'updating health check type' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', health_check_type: 'process' }) }
          let(:manifest_process_update_message) { message.manifest_process_update_messages.first }
          let(:process) { ProcessModel.make }
          let(:app) { process.app }

          context 'when the request is invalid' do
            let(:message) { AppManifestMessage.create_from_yml({ health_check_type: 'http' }) }

            before do
              allow(process_update).
                to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('invalid process'))
            end

            it 'bubbles up the error' do
              expect do
                app_apply_manifest.apply(app.guid, message)
              end.to raise_error(ProcessUpdate::InvalidProcess, 'invalid process')
            end
          end

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls ProcessUpdate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ProcessUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(process_update).to have_received(:update).with(process, manifest_process_update_message, ManifestStrategy)
            end
          end
        end

        describe 'updating readiness health check type' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', readiness_health_check_type: 'port' }) }
          let(:manifest_process_update_message) { message.manifest_process_update_messages.first }
          let(:process) { ProcessModel.make }
          let(:app) { process.app }

          context 'when the request is invalid' do
            let(:message) { AppManifestMessage.create_from_yml({ readiness_health_check_type: 'http' }) }

            before do
              allow(process_update).
                to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('invalid process'))
            end

            it 'bubbles up the error' do
              expect do
                app_apply_manifest.apply(app.guid, message)
              end.to raise_error(ProcessUpdate::InvalidProcess, 'invalid process')
            end
          end

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls ProcessUpdate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ProcessUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(process_update).to have_received(:update).with(process, manifest_process_update_message, ManifestStrategy)
            end
          end
        end

        describe 'updating health check invocation_timeout' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', health_check_invocation_timeout: 47 }) }
          let(:manifest_process_update_message) { message.manifest_process_update_messages.first }
          let(:process) { ProcessModel.make }
          let(:app) { process.app }

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls ProcessUpdate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ProcessUpdate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(process_update).to have_received(:update).with(process, manifest_process_update_message, ManifestStrategy)
            end
          end
        end

        describe 'updating sidecars' do
          let(:app) { AppModel.make }
          let!(:sidecar) { SidecarModel.make(name: 'existing-sidecar', app: app) }
          let(:message) do
            AppManifestMessage.create_from_yml({ name: 'blah',
                                                 'sidecars' => [
                                                   {
                                                     'process_types' => ['web'],
                                                     'name' => 'new-sidecar',
                                                     'command' => 'rackup',
                                                     'memory' => '2G'
                                                   },
                                                   {
                                                     'process_types' => ['web'],
                                                     'name' => 'existing-sidecar',
                                                     'command' => 'rackup'
                                                   }
                                                 ] })
          end

          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
            expect(SidecarUpdate).to have_received(:update).with(sidecar, message.sidecar_create_messages.last)
            expect(SidecarCreate).to have_received(:create).with(app.guid, message.sidecar_create_messages.first)
          end
        end

        describe 'updating routes' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', routes: [{ route: 'http://tater.tots.com/tabasco' }] }) }
          let(:manifest_routes_update_message) { message.manifest_routes_update_message }
          let(:process) { ProcessModel.make }
          let(:app) { process.app }

          context 'when the request is valid' do
            it 'returns the app' do
              expect(
                app_apply_manifest.apply(app.guid, message)
              ).to eq(app)
            end

            it 'calls ManifestRouteUpdate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).to have_received(:update).with(app.guid, manifest_routes_update_message, user_audit_info)
            end
          end
        end

        describe 'updating with a random-route' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', random_route: true }) }
          let(:manifest_routes_update_message) { message.manifest_routes_update_message }
          let(:process) { ProcessModel.make }
          let(:app) { process.app }

          context 'when the app has no routes and the message specifies no routes' do
            it 'provides a random route' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).to have_received(:update) do |guid, msg, audit_info|
                expect(guid).to eq(app.guid)
                expect(msg.routes.first[:route]).to eq("#{app.name}-spiffy/donut.#{Domain.first.name}")
                expect(audit_info).to eq(user_audit_info)
              end
            end

            context 'when there is no shared domain' do
              let(:domain) { PrivateDomain.make(owning_organization: app.organization) }

              before do
                Domain.dataset.destroy
                domain # ensure domain is created after the dataset is truncated
              end

              it 'provides a random route within a domain scoped to the apps organization' do
                app_apply_manifest.apply(app.guid, message)
                expect(ManifestRouteUpdate).to have_received(:update) do |guid, msg, audit_info|
                  expect(guid).to eq(app.guid)
                  expect(msg.routes.first[:route]).to eq("#{app.name}-spiffy/donut.#{domain.name}")
                  expect(audit_info).to eq(user_audit_info)
                end
              end
            end

            context 'when there is no domains' do
              before do
                Domain.dataset.destroy
              end

              it 'fails with a NoDefaultDomain error' do
                expect do
                  app_apply_manifest.apply(app.guid, message)
                end.to raise_error(AppApplyManifest::NoDefaultDomain, 'No default domains available')
              end
            end
          end

          context 'when the app has existing routes' do
            let(:route1) { Route.make(space: app.space) }
            let!(:route_mapping1) { RouteMappingModel.make(app: app, route: route1, process_type: process.type) }

            it 'ignores the random_route' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).not_to have_received(:update)
            end
          end

          context 'when the message specifies routes' do
            let(:message) do
              AppManifestMessage.create_from_yml({ name: 'blah', random_route: true,
                                                   routes: [{ route: 'billy.tabasco.com' }] })
            end

            it 'ignores the random_route but uses the routes' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).to have_received(:update).with(app.guid, manifest_routes_update_message, user_audit_info)
            end
          end

          context 'when the message specifies an empty list of routes' do
            let(:message) do
              AppManifestMessage.create_from_yml({ name: 'blah', random_route: true,
                                                   routes: [] })
            end

            it 'ignores the random_route' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).to have_received(:update).with(app.guid, manifest_routes_update_message, user_audit_info)
            end
          end
        end

        describe 'updating with a default-route' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', default_route: true }) }
          let(:manifest_routes_update_message) { message.manifest_routes_update_message }
          let(:process) { ProcessModel.make }
          let(:app) { process.app }

          context 'when the app has no routes and the message specifies no routes' do
            it 'provides a default route' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).to have_received(:update) do |guid, msg, audit_info|
                expect(guid).to eq(app.guid)
                expect(msg.routes.first[:route]).to eq("#{app.name}.#{Domain.first.name}")
                expect(audit_info).to eq(user_audit_info)
              end
            end

            context 'when the app name has special characters' do
              let(:message) { AppManifestMessage.create_from_yml({ name: 'blah!@#', default_route: true }) }
              let(:app_model) { AppModel.make(name: 'blah!@#') }

              it 'fails with a useful error message' do
                expect do
                  app_apply_manifest.apply(app_model.guid, message)
                end.to raise_error(AppApplyManifest::Error,
                                   /Failed to create default route from app name: Host must be either "\*" or contain only alphanumeric characters, "_", or "-"/)
              end
            end

            context 'when the app name is too long' do
              let(:app_name) { 'a' * 100 }
              let(:message) { AppManifestMessage.create_from_yml({ name: app_name, default_route: true }) }
              let(:app_model) { AppModel.make(name: app_name) }

              it 'fails with a useful error' do
                expect do
                  app_apply_manifest.apply(app_model.guid, message)
                end.to raise_error(AppApplyManifest::Error, 'Failed to create default route from app name: Host cannot exceed 63 characters')
              end
            end

            context 'when there is no shared domain' do
              let(:domain) { PrivateDomain.make(owning_organization: app.organization) }

              before do
                Domain.dataset.destroy
                domain # ensure domain is created after the dataset is truncated
              end

              it 'provides a default route within a domain scoped to the apps organization' do
                app_apply_manifest.apply(app.guid, message)
                expect(ManifestRouteUpdate).to have_received(:update) do |guid, msg, audit_info|
                  expect(guid).to eq(app.guid)
                  expect(msg.routes.first[:route]).to eq("#{app.name}.#{domain.name}")
                  expect(audit_info).to eq(user_audit_info)
                end
              end
            end

            context 'when there is no domains' do
              before do
                Domain.dataset.destroy
              end

              it 'fails with a NoDefaultDomain error' do
                expect do
                  app_apply_manifest.apply(app.guid, message)
                end.to raise_error(AppApplyManifest::NoDefaultDomain, 'No default domains available')
              end
            end
          end

          context 'when the app has existing routes' do
            let(:route1) { Route.make(space: app.space) }
            let!(:route_mapping1) { RouteMappingModel.make(app: app, route: route1, process_type: process.type) }

            it 'ignores the default_route' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).not_to have_received(:update)
            end
          end

          context 'when the message specifies routes' do
            let(:message) do
              AppManifestMessage.create_from_yml({ name: 'blah', default_route: true,
                                                   routes: [{ route: 'billy.tabasco.com' }] })
            end

            it 'ignores the default_route but uses the routes' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).to have_received(:update).with(app.guid, manifest_routes_update_message, user_audit_info)
            end
          end

          context 'when the message specifies an empty list of routes' do
            let(:message) do
              AppManifestMessage.create_from_yml({ name: 'blah', default_route: true,
                                                   routes: [] })
            end

            it 'ignores the default_route' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).to have_received(:update).with(app.guid, manifest_routes_update_message, user_audit_info)
            end
          end
        end

        describe 'deleting existing routes' do
          let(:manifest_routes_update_message) { message.manifest_routes_update_message }
          let(:process) { ProcessModel.make }
          let(:app) { process.app }
          let(:route1) { Route.make(space: app.space) }
          let(:route2) { Route.make(space: app.space) }
          let!(:route_mapping1) { RouteMappingModel.make(app: app, route: route1, process_type: process.type) }
          let!(:route_mapping2) { RouteMappingModel.make(app: app, route: route2, process_type: process.type) }

          context 'when no_route is true' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', no_route: true, random_route: true }) }

            context 'when the request is valid' do
              it 'returns the app' do
                expect(
                  app_apply_manifest.apply(app.guid, message)
                ).to eq(app)
              end

              it 'calls RouteMappingDelete with the routes' do
                app_apply_manifest.apply(app.guid, message)
                expect(RouteMappingDelete).to have_received(:new).with(user_audit_info, manifest_triggered: true)
                expect(route_mapping_delete).to have_received(:delete).with(array_including(route_mapping1, route_mapping2))
              end

              it 'does not generate a random route' do
                app_apply_manifest.apply(app.guid, message)
                expect(ManifestRouteUpdate).not_to have_received(:update)
              end
            end
          end

          context 'when no_route is false' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', no_route: false }) }

            context 'when the request is valid' do
              it 'returns the app' do
                expect(
                  app_apply_manifest.apply(app.guid, message)
                ).to eq(app)
              end

              it 'does not call RouteMappingDelete' do
                app_apply_manifest.apply(app.guid, message)
                expect(route_mapping_delete).not_to have_received(:delete)
              end
            end
          end
        end

        describe 'creating service bindings' do
          let(:space) { Space.make }
          let(:app) { AppModel.make(space:) }

          before do
            TestConfig.override(volume_services_enabled: false)
          end

          context 'valid request with list of services' do
            let!(:service_instance) { ManagedServiceInstance.make(name: 'si-name', space: space) }
            let!(:service_instance_2) { ManagedServiceInstance.make(name: 'si2-name', space: space) }
            let(:binding_name) { Sham.name }
            let(:message) do
              AppManifestMessage.create_from_yml({ services: [service_instance.name,
                                                              { 'name' => service_instance_2.name, parameters: { 'foo' => 'bar' }, binding_name: binding_name }] })
            end

            let(:service_binding_create_message_1) { instance_double(ServiceCredentialAppBindingCreateMessage) }
            let(:service_binding_create_message_2) { instance_double(ServiceCredentialAppBindingCreateMessage) }

            before do
              allow(ServiceCredentialAppBindingCreateMessage).to receive(:new).and_return(service_binding_create_message_1, service_binding_create_message_2)
              allow(service_cred_binding_create).to receive(:bind) { ServiceBinding.make }
              allow_any_instance_of(ServiceBinding).to receive(:terminal_state?).and_return true

              allow(service_cred_binding_create).to receive(:precursor).and_return(ServiceBinding.make)
              allow(service_binding_create_message_1).to receive(:audit_hash).and_return({ foo: 'bar-1' })
              allow(service_binding_create_message_1).to receive(:parameters)
              allow(service_binding_create_message_2).to receive_messages(audit_hash: { foo: 'bar-2' }, parameters: { 'foo' => 'bar' })
            end

            it 'creates an action with the right arguments' do
              app_apply_manifest.apply(app.guid, message)

              expect(V3::ServiceCredentialBindingAppCreate).to have_received(:new).with(user_audit_info, { foo: 'bar-1' }, manifest_triggered: true)
              expect(V3::ServiceCredentialBindingAppCreate).to have_received(:new).with(user_audit_info, { foo: 'bar-2' }, manifest_triggered: true)
            end

            it 'calls precursor with the correct arguments for each binding' do
              app_apply_manifest.apply(app.guid, message)

              expect(ServiceCredentialAppBindingCreateMessage).to have_received(:new).with(
                type: AppApplyManifest::SERVICE_BINDING_TYPE,
                name: nil,
                parameters: {},
                relationships: {
                  service_instance: {
                    data: {
                      guid: service_instance.guid
                    }
                  },
                  app: {
                    data: {
                      guid: app.guid
                    }
                  }
                }
              )
              expect(ServiceCredentialAppBindingCreateMessage).to have_received(:new).with(
                type: AppApplyManifest::SERVICE_BINDING_TYPE,
                name: binding_name,
                parameters: { foo: 'bar' },
                relationships: {
                  service_instance: {
                    data: {
                      guid: service_instance_2.guid
                    }
                  },
                  app: {
                    data: {
                      guid: app.guid
                    }
                  }
                }
              )

              expect(service_cred_binding_create).to have_received(:precursor).
                with(service_instance, app: app, volume_mount_services_enabled: false, message: service_binding_create_message_1)

              expect(service_cred_binding_create).to have_received(:precursor).
                with(service_instance_2, app: app, volume_mount_services_enabled: false, message: service_binding_create_message_2)
            end

            it 'calls bind with the right arguments' do
              service_binding_1 = instance_double(ServiceBinding)
              service_binding_2 = instance_double(ServiceBinding)

              allow(service_cred_binding_create).to receive(:precursor).and_return(
                service_binding_1,
                service_binding_2
              )

              app_apply_manifest.apply(app.guid, message)

              expect(service_cred_binding_create).to have_received(:bind).with(service_binding_1, parameters: nil, accepts_incomplete: false)
              expect(service_cred_binding_create).to have_received(:bind).with(service_binding_2, parameters: { 'foo' => 'bar' }, accepts_incomplete: false)
            end

            it 'wraps the error when precursor errors' do
              allow(service_cred_binding_create).to receive(:precursor).and_raise('fake binding error')

              expect do
                app_apply_manifest.apply(app.guid, message)
              end.to raise_error(AppApplyManifest::ServiceBindingError, /For service 'si-name': fake binding error/)
            end

            context 'service binding already exists' do
              let(:message) { AppManifestMessage.create_from_yml({ services: [service_instance.name] }) }
              let!(:binding) { ServiceBinding.make(service_instance:, app:) }

              it 'does not create the binding' do
                app_apply_manifest.apply(app.guid, message)

                expect(service_cred_binding_create).not_to have_received(:bind)
              end

              context "last binding operation is 'create failed'" do
                before do
                  binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'failed' })
                end

                it 'recreates the binding' do
                  allow(service_cred_binding_create).to receive(:precursor).and_return(binding)

                  app_apply_manifest.apply(app.guid, message)

                  expect(service_cred_binding_create).to have_received(:bind).with(binding, parameters: nil, accepts_incomplete: false)
                end
              end
            end

            context 'volume_services_enabled' do
              let(:message) { AppManifestMessage.create_from_yml({ services: [service_instance.name] }) }

              before do
                TestConfig.override(volume_services_enabled: true)
              end

              it 'passes the volume_services_enabled_flag to ServiceBindingCreate' do
                app_apply_manifest.apply(app.guid, message)

                expect(service_cred_binding_create).to have_received(:precursor).
                  with(service_instance, app: app, volume_mount_services_enabled: true, message: service_binding_create_message_1)
              end
            end

            context 'service binding errors' do
              context 'bind happens async' do
                context 'action starts async binding' do
                  before do
                    allow(service_cred_binding_create).to receive(:bind).with(anything, parameters: nil, accepts_incomplete: false).and_return({ async: true })
                  end

                  it 'raises an error' do
                    expect do
                      app_apply_manifest.apply(app.guid, message)
                    end.to raise_error(AppApplyManifest::ServiceBindingError,
                                       /For service 'si-name': The service broker responded asynchronously when a synchronous bind was requested./)
                  end
                end
              end
            end

            context 'service broker support sync or async bindings' do
              context 'action prefers sync binding' do
                let(:binding1) { ServiceBinding.make(service_instance:, app:) }
                let(:binding2) { ServiceBinding.make(service_instance: service_instance_2, app: app) }

                before do
                  allow_any_instance_of(ServiceBinding).to receive(:terminal_state?).and_call_original
                  allow_any_instance_of(AppApplyManifest).to receive(:sleep)

                  precursor_count = 0
                  allow(service_cred_binding_create).to receive(:precursor) do
                    precursor_count += 1
                    if precursor_count == 1
                      binding1
                    else
                      binding2
                    end
                  end

                  count = 0
                  allow(service_cred_binding_create).to receive(:bind).with(anything, accepts_incomplete: false) do
                    count += 1
                    if count == 1
                      ServiceBindingOperation.make(type: 'create', state: 'succeeded', service_binding: binding1)
                      binding1
                    else
                      ServiceBindingOperation.make(type: 'create', state: 'succeeded', service_binding: binding2)
                      binding2
                    end
                  end
                end

                it 'completes binding synchronously and does not try to poll' do
                  expect(service_cred_binding_create).to receive(:poll).exactly(0).times

                  app_apply_manifest.apply(app.guid, message)
                end
              end
            end

            context 'broker only supports async bindings' do
              context 'action starts async binding' do
                let(:binding1) { ServiceBinding.make(service_instance:, app:) }
                let(:binding2) { ServiceBinding.make(service_instance: service_instance_2, app: app) }

                before do
                  response = double(body: '{}', code: '422')
                  allow(service_cred_binding_create).to receive(:bind).
                    with(anything, parameters: anything, accepts_incomplete: false).and_raise VCAP::Services::ServiceBrokers::V2::Errors::AsyncRequired.new('fake message',
                                                                                                                                                            'POST', response)
                  allow_any_instance_of(ServiceBinding).to receive(:terminal_state?).and_call_original
                  allow_any_instance_of(AppApplyManifest).to receive(:sleep)

                  precursor_count = 0
                  allow(service_cred_binding_create).to receive(:precursor) do
                    precursor_count += 1
                    if precursor_count == 1
                      binding1
                    else
                      binding2
                    end
                  end

                  count = 0
                  allow(service_cred_binding_create).to receive(:bind).with(anything, parameters: anything, accepts_incomplete: true) do
                    count += 1
                    if count == 1
                      ServiceBindingOperation.make(type: 'create', state: 'initial', service_binding: binding1)
                      binding1
                    else
                      ServiceBindingOperation.make(type: 'create', state: 'initial', service_binding: binding2)
                      binding2
                    end
                  end
                end

                it 'polls service bindings until they are complete' do
                  allow(service_cred_binding_create).to receive(:poll).and_return(V3::ServiceBindingCreate::ContinuePolling.call(1.second),
                                                                                  V3::ServiceBindingCreate::ContinuePolling.call(1.second),
                                                                                  V3::ServiceBindingCreate::PollingFinished,
                                                                                  V3::ServiceBindingCreate::ContinuePolling.call(1.second),
                                                                                  V3::ServiceBindingCreate::PollingFinished)

                  expect(service_cred_binding_create).to receive(:poll).exactly(5).times
                  expect(app_apply_manifest).to receive(:sleep).with(1).exactly(3).times

                  app_apply_manifest.apply(app.guid, message)
                end

                it 'polls service bindings with the default sleep value' do
                  allow(service_cred_binding_create).to receive(:poll).and_return(V3::ServiceBindingCreate::ContinuePolling.call(nil),
                                                                                  V3::ServiceBindingCreate::ContinuePolling.call(nil),
                                                                                  V3::ServiceBindingCreate::PollingFinished,
                                                                                  V3::ServiceBindingCreate::ContinuePolling.call(nil),
                                                                                  V3::ServiceBindingCreate::PollingFinished)

                  expect(service_cred_binding_create).to receive(:poll).exactly(5).times
                  expect(app_apply_manifest).to receive(:sleep).with(5).exactly(3).times

                  app_apply_manifest.apply(app.guid, message)
                end

                it 'verifies exception is thrown if maximum polling duration is exceeded' do
                  TestConfig.override(max_manifest_service_binding_poll_duration_in_seconds: 15)
                  allow_any_instance_of(AppApplyManifest).to receive(:sleep) do |_action, seconds|
                    Timecop.travel(seconds.from_now)
                  end
                  allow(service_cred_binding_create).to receive(:poll).and_return(V3::ServiceBindingCreate::ContinuePolling.call(20.seconds),
                                                                                  V3::ServiceBindingCreate::ContinuePolling.call(20.seconds),
                                                                                  V3::ServiceBindingCreate::PollingFinished)
                  expect { app_apply_manifest.apply(app.guid, message) }.to raise_error(AppApplyManifest::ServiceBindingError)

                  expect(binding1.last_operation.state).to eq('failed')
                  expect(binding1.last_operation.description).to eq('Polling exceed the maximum polling duration')

                  orphan_mitigation_job = Delayed::Job.first
                  expect(orphan_mitigation_job).not_to be_nil
                  expect(orphan_mitigation_job).to be_a_fully_wrapped_job_of Jobs::Services::DeleteOrphanedBinding
                end

                it 'has a maximum retry_after' do
                  allow(service_cred_binding_create).to receive(:poll).and_return(V3::ServiceBindingCreate::ContinuePolling.call(24.hours),
                                                                                  V3::ServiceBindingCreate::PollingFinished)
                  expect(app_apply_manifest).to receive(:sleep).with(60)

                  app_apply_manifest.apply(app.guid, message)
                end

                context 'async binding fails' do
                  let(:binding) { ServiceBinding.make(service_instance:, app:) }

                  before do
                    allow(service_cred_binding_create).to receive(:precursor) { binding }

                    allow(service_cred_binding_create).to receive(:bind).with(anything, parameters: anything, accepts_incomplete: true) do
                      ServiceBindingOperation.make(type: 'create', state: 'initial', service_binding: binding)
                      binding
                    end

                    count = 0
                    allow(service_cred_binding_create).to receive(:poll) do
                      count += 1
                      raise V3::LastOperationFailedState unless count < 3

                      V3::ServiceBindingCreate::ContinuePolling.call(1.second)
                    end
                  end

                  it 'polls service bindings until they are in a terminal state' do
                    expect(service_cred_binding_create).to receive(:poll).exactly(3).times
                    expect(app_apply_manifest).to receive(:sleep).with(1).twice
                    expect do
                      app_apply_manifest.apply(app.guid, message)
                    end.to raise_error(AppApplyManifest::ServiceBindingError)
                  end
                end
              end

              context 'bind fails with BindingNotRetrievable' do
                before do
                  error = V3::ServiceBindingCreate::BindingNotRetrievable.new('The broker responded asynchronously but does not support fetching binding data.')
                  allow(service_cred_binding_create).to receive(:bind).and_raise(error)
                end

                it 'fails with async error' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError,
                                     /For service 'si-name': The broker responded asynchronously but does not support fetching binding data./)
                end
              end
            end

            context 'service binding errors' do
              context 'generic binding errors' do
                before do
                  allow(service_cred_binding_create).to receive(:bind).and_raise('fake binding error')
                end

                it 'decorates the error with the name of the service instance' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError, /For service 'si-name': fake binding error/)
                end
              end

              context 'when a create is in progress for the same binding' do
                let!(:binding) do
                  binding = ServiceBinding.make(service_instance:, app:)
                  binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'in progress' })
                  binding
                end

                it 'fails with a service binding error' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError, /For service 'si-name': A binding is being created. Retry this operation later./)
                end
              end

              context 'when a delete is in progress for the same binding' do
                let!(:binding) do
                  binding = ServiceBinding.make(service_instance:, app:)
                  binding.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'in progress' })
                  binding
                end

                it 'fails with a service binding error' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError, /For service 'si-name': A binding is being deleted. Retry this operation later./)
                end
              end

              context 'when a delete failed for the same binding' do
                let!(:binding) do
                  binding = ServiceBinding.make(service_instance:, app:)
                  binding.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'failed' })
                  binding
                end

                it 'fails with a service binding error' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError,
                                     /For service 'si-name': A binding failed to be deleted. Resolve the issue with this binding before retrying this operation./)
                end
              end
            end

            context 'different service instance states' do
              context 'when the last operation state is create in progress' do
                before do
                  service_instance.save_with_new_operation({}, { type: 'create', state: 'in progress' })
                  allow(service_cred_binding_create).to receive(:precursor).and_raise(V3::ServiceCredentialBindingAppCreate::UnprocessableCreate,
                                                                                      'There is an operation in progress for the service instance')
                end

                it 'fails with a service binding error' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError,
                                     "For service '#{service_instance.name}': There is an operation in progress for the service instance")
                end
              end

              context 'when the last operation state is create succeeded' do
                before do
                  service_instance.save_with_new_operation({}, { type: 'create', state: 'succeeded' })
                end

                it 'creates the binding' do
                  service_binding_1 = instance_double(ServiceBinding)
                  service_binding_2 = instance_double(ServiceBinding)

                  allow(service_cred_binding_create).to receive(:precursor).and_return(
                    service_binding_1,
                    service_binding_2
                  )

                  app_apply_manifest.apply(app.guid, message)

                  expect(service_cred_binding_create).to have_received(:bind).with(service_binding_1, parameters: nil, accepts_incomplete: false)
                  expect(service_cred_binding_create).to have_received(:bind).with(service_binding_2, parameters: { 'foo' => 'bar' }, accepts_incomplete: false)
                end
              end

              context 'when the last operation state is create failed' do
                before do
                  service_instance.save_with_new_operation({}, { type: 'create', state: 'failed' })
                  allow(service_cred_binding_create).to receive(:precursor).and_raise(V3::ServiceCredentialBindingAppCreate::UnprocessableCreate, 'Service instance not found')
                end

                it 'fails with a service binding error' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError,
                                     "For service '#{service_instance.name}': Service instance not found")
                end
              end

              context 'when the last operation state is update in progress' do
                before do
                  service_instance.save_with_new_operation({}, { type: 'update', state: 'in progress' })
                  allow(service_cred_binding_create).to receive(:precursor).and_raise(V3::ServiceCredentialBindingAppCreate::UnprocessableCreate,
                                                                                      'There is an operation in progress for the service instance')
                end

                it 'fails with a service binding error' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError,
                                     "For service '#{service_instance.name}': There is an operation in progress for the service instance")
                end
              end

              context 'when the last operation state is update succeeded' do
                before do
                  service_instance.save_with_new_operation({}, { type: 'update', state: 'succeeded' })
                end

                it 'creates the binding' do
                  service_binding_1 = instance_double(ServiceBinding)
                  service_binding_2 = instance_double(ServiceBinding)

                  allow(service_cred_binding_create).to receive(:precursor).and_return(
                    service_binding_1,
                    service_binding_2
                  )

                  app_apply_manifest.apply(app.guid, message)

                  expect(service_cred_binding_create).to have_received(:bind).with(service_binding_1, parameters: nil, accepts_incomplete: false)
                  expect(service_cred_binding_create).to have_received(:bind).with(service_binding_2, parameters: { 'foo' => 'bar' }, accepts_incomplete: false)
                end
              end

              context 'when the last operation state is update failed' do
                before do
                  service_instance.save_with_new_operation({}, { type: 'update', state: 'failed' })
                end

                it 'creates the binding' do
                  service_binding_1 = instance_double(ServiceBinding)
                  service_binding_2 = instance_double(ServiceBinding)

                  allow(service_cred_binding_create).to receive(:precursor).and_return(
                    service_binding_1,
                    service_binding_2
                  )

                  app_apply_manifest.apply(app.guid, message)

                  expect(service_cred_binding_create).to have_received(:bind).with(service_binding_1, parameters: nil, accepts_incomplete: false)
                  expect(service_cred_binding_create).to have_received(:bind).with(service_binding_2, parameters: { 'foo' => 'bar' }, accepts_incomplete: false)
                end
              end

              context 'when the last operation state is delete in progress' do
                before do
                  service_instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
                  allow(service_cred_binding_create).to receive(:precursor).and_raise(V3::ServiceCredentialBindingAppCreate::UnprocessableCreate,
                                                                                      'There is an operation in progress for the service instance')
                end

                it 'fails with a service binding error' do
                  expect do
                    app_apply_manifest.apply(app.guid, message)
                  end.to raise_error(AppApplyManifest::ServiceBindingError,
                                     "For service '#{service_instance.name}': There is an operation in progress for the service instance")
                end
              end

              context 'when the last operation state is delete failed' do
                before do
                  service_instance.save_with_new_operation({}, { type: 'delete', state: 'failed' })
                end

                it 'creates the binding' do
                  service_binding_1 = instance_double(ServiceBinding)
                  service_binding_2 = instance_double(ServiceBinding)

                  allow(service_cred_binding_create).to receive(:precursor).and_return(
                    service_binding_1,
                    service_binding_2
                  )

                  app_apply_manifest.apply(app.guid, message)

                  expect(service_cred_binding_create).to have_received(:bind).with(service_binding_1, parameters: nil, accepts_incomplete: false)
                  expect(service_cred_binding_create).to have_received(:bind).with(service_binding_2, parameters: { 'foo' => 'bar' }, accepts_incomplete: false)
                end
              end
            end
          end
        end

        describe 'when the app no longer exists' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', instances: 4 }) }
          let(:app_guid) { 'fake-guid' }

          it 'raises a NotFound error' do
            expect do
              app_apply_manifest.apply(app_guid, message)
            end.to raise_error(CloudController::Errors::NotFound, "App with guid '#{app_guid}' not found")
          end
        end
      end
    end

    context 'when we want to test manifest mechanisms' do
      subject(:app_apply_manifest) { AppApplyManifest.new(user_audit_info) }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'x@y.com', user_guid: 'hi guid') }

      describe '#apply' do
        context 'when changing memory' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', memory: '256MB' }) }
          let(:process) { ProcessModel.make(memory: 512, state: ProcessModel::STARTED, type: 'web') }
          let(:app) { process.app }

          it "doesn't change the process's version" do
            app.update(name: 'blah')
            version = process.version
            app_apply_manifest.apply(app.guid, message)
            expect(process.reload.version).to eq(version)
            expect(process.memory).to eq(256)
          end

          context 'when there are additional app web processes' do
            let(:process2) { ProcessModel.make(memory: 513, state: ProcessModel::STARTED, type: 'web', app: app, created_at: process.created_at + 1) }

            it 'operates on the most recent process for a given app' do
              app.update(name: 'blah')
              version = process.version
              version2 = process2.version
              app_apply_manifest.apply(app.guid, message)
              process.reload
              process2.reload
              expect(process.version).to eq(version)
              expect(process.memory).to eq(512)
              expect(process2.version).to eq(version2)
              expect(process2.memory).to eq(256)
            end
          end
        end
      end
    end
  end
end
