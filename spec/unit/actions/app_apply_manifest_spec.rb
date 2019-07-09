require 'spec_helper'
require 'actions/app_apply_manifest'

module VCAP::CloudController
  RSpec.describe AppApplyManifest do
    context 'when everything is mocked out' do
      subject(:app_apply_manifest) { AppApplyManifest.new(user_audit_info) }
      let(:user_audit_info) { instance_double(UserAuditInfo) }
      let(:process_scale) { instance_double(ProcessScale) }
      let(:route_mapping_delete) { instance_double(RouteMappingDelete) }
      let(:app_update) { instance_double(AppUpdate) }
      let(:app_patch_env) { instance_double(AppPatchEnvironmentVariables) }
      let(:process_update) { instance_double(ProcessUpdate) }
      let(:process_create) { instance_double(ProcessCreate) }
      let(:service_binding_create) { instance_double(ServiceBindingCreate) }
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

          allow(ServiceBindingCreate).
            to receive(:new).and_return(service_binding_create)
          allow(service_binding_create).to receive(:create)

          allow(AppPatchEnvironmentVariables).
            to receive(:new).and_return(app_patch_env)
          allow(app_patch_env).to receive(:patch)
        end

        describe 'scaling a process' do
          describe 'scaling instances' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', instances: 4 }, {}) }
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
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', memory: '256MB' }, {}) }
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
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', buildpack: buildpack.name }, {}) }
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

          context 'when the request is invalid due to failure to update the app' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', buildpack: buildpack.name }, {}) }

            before do
              allow(app_update).
                to receive(:update).and_raise(AppUpdate::InvalidApp.new('invalid app'))
            end

            it 'bubbles up the error' do
              expect {
                app_apply_manifest.apply(app.guid, message)
              }.to raise_error(AppUpdate::InvalidApp, 'invalid app')
            end
          end
        end

        describe 'updating stack' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'stack-test', stack: 'cflinuxfs3' }, {}) }
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
            let(:message) { AppManifestMessage.create_from_yml({ name: 'stack-test', stack: 'no-such-stack' }, {}) }

            before do
              allow(app_update).
                to receive(:update).and_raise(AppUpdate::InvalidApp.new('invalid app'))
            end

            it 'bubbles up the error' do
              expect {
                app_apply_manifest.apply(app.guid, message)
              }.to raise_error(AppUpdate::InvalidApp, 'invalid app')
            end
          end
        end

        describe 'updating environment variables' do
          let(:message) { AppManifestMessage.create_from_yml({ env: { 'foo': 'bar' } }, {}) }
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
            let(:message) { AppManifestMessage.create_from_yml({ env: 'not-a-hash' }, {}) }

            before do
              allow(app_patch_env).
                to receive(:patch).and_raise(AppPatchEnvironmentVariables::InvalidApp.new('invalid app'))
            end

            it 'bubbles up the error' do
              expect {
                app_apply_manifest.apply(app.guid, message)
              }.to raise_error(AppPatchEnvironmentVariables::InvalidApp, 'invalid app')
            end
          end
        end

        describe 'updating command' do
          let(:message) { AppManifestMessage.create_from_yml({ command: 'new-command' }, {}) }
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
            let(:message) { AppManifestMessage.create_from_yml({ command: '' }, {}) }

            before do
              allow(process_update).
                to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('invalid process'))
            end

            it 'bubbles up the error' do
              expect {
                app_apply_manifest.apply(app.guid, message)
              }.to raise_error(ProcessUpdate::InvalidProcess, 'invalid process')
            end
          end
        end

        describe 'updating multiple process attributes' do
          let(:message) { AppManifestMessage.create_from_yml({
            processes: [
              { type: 'web', command: 'web-command', instances: 2 },
              { type: 'worker', command: 'worker-command', instances: 3 },
            ] },
            {}
          )
          }
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
            let(:message) { AppManifestMessage.create_from_yml({ command: '' }, {}) }

            before do
              allow(process_update).
                to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('invalid process'))
            end

            it 'bubbles up the error' do
              expect {
                app_apply_manifest.apply(app.guid, message)
              }.to raise_error(ProcessUpdate::InvalidProcess, 'invalid process')
            end
          end
        end

        describe 'creating a new process' do
          let(:message) do
            AppManifestMessage.create_from_yml({
              processes: [
                { type: 'potato', command: 'potato-command', instances: 3 },
              ] },
              {}
            )
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
                    { type: 'potato', instances: 3 },
                  ] },
                  {}
                )
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
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', health_check_type: 'process' }, {}) }
          let(:manifest_process_update_message) { message.manifest_process_update_messages.first }
          let(:process) { ProcessModel.make }
          let(:app) { process.app }

          context 'when the request is invalid' do
            let(:message) { AppManifestMessage.create_from_yml({ health_check_type: 'http' }, {}) }

            before do
              allow(process_update).
                to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('invalid process'))
            end

            it 'bubbles up the error' do
              expect {
                app_apply_manifest.apply(app.guid, message)
              }.to raise_error(ProcessUpdate::InvalidProcess, 'invalid process')
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
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', health_check_invocation_timeout: 47 }, {}) }
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
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah',
            'sidecars' => [
              {
                'process_types' => ['web'],
                'name' => 'my-sidecar',
                'command' => 'rackup',
              },
              {
                'process_types' => ['web'],
                'name' => 'existing-sidecar',
                'command' => 'rackup',
              }
            ]
          },
          {})
          }

          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
            expect(SidecarUpdate).to have_received(:update).with(sidecar, message.sidecar_create_messages.last)
            expect(SidecarCreate).to have_received(:create).with(app.guid, message.sidecar_create_messages.first)
          end
        end

        describe 'updating routes' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', routes: [{ 'route': 'http://tater.tots.com/tabasco' }] }, {}) }
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
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', random_route: true }, {}) }
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
                expect {
                  app_apply_manifest.apply(app.guid, message)
                }.to raise_error(AppApplyManifest::NoDefaultDomain, 'No domains available for random route')
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
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', random_route: true,
                                                                 routes: [{ route: 'billy.tabasco.com' }] }, {})
            }

            it 'ignores the random_route but uses the routes' do
              app_apply_manifest.apply(app.guid, message)
              expect(ManifestRouteUpdate).to have_received(:update).with(app.guid, manifest_routes_update_message, user_audit_info)
            end
          end

          context 'when the message specifies an empty list of routes' do
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', random_route: true,
                                                                 routes: [] }, {})
            }

            it 'ignores the random_route' do
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
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', no_route: true, random_route: true }, {}) }

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
            let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', no_route: false }, {}) }

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
          let(:message) { AppManifestMessage.create_from_yml({ services: ['si-name', { name: 'name', parameters: { 'foo' => 'bar' } }] }, {}) } # why defined here?
          let(:space) { Space.make }
          let(:app) { AppModel.make(space: space) }

          before do
            TestConfig.override(volume_services_enabled: false)
          end

          context 'valid request with list of services' do
            let(:message) { AppManifestMessage.create_from_yml({ services: ['si-name', { 'name' => 'si2-name', parameters: { 'foo' => 'bar' } }] }, {}) }
            let!(:service_instance) { ManagedServiceInstance.make(name: 'si-name', space: space) }
            let!(:service_instance_2) { ManagedServiceInstance.make(name: 'si2-name', space: space) }

            it 'calls ServiceBindingCreate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ServiceBindingCreate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(service_binding_create).to have_received(:create).
                with(app, service_instance, instance_of(ServiceBindingCreateMessage), false, false)
              expect(service_binding_create).to have_received(:create).
                with(app, service_instance_2, instance_of(ServiceBindingCreateMessage), false, false)
            end

            context 'overriding service_binding_create.create' do
              let(:service_binding_create2) { instance_double(ServiceBindingCreate) }

              before do
                allow(ServiceBindingCreate).to receive(:new).and_return(service_binding_create2)
              end

              it 'calls ServiceBindingCreate.create with the correct type' do
                i = 0
                allow(service_binding_create2).to receive(:create) do |_, _, binding_message, _|
                  expect(binding_message.type).to eq('app')
                  i += 1
                end
                app_apply_manifest.apply(app.guid, message)
                expect(i).to eq(2)
              end
            end

            context 'service binding already exists' do
              let(:message) { AppManifestMessage.create_from_yml({ services: ['si-name'] }, {}) }
              let!(:binding) { ServiceBinding.make(service_instance: service_instance, app: app) }

              it 'does not create the binding' do
                app_apply_manifest.apply(app.guid, message)
                expect(service_binding_create).to_not have_received(:create)
              end
            end

            context 'when theres a service instance in another space' do
              let(:new_space) { Space.make }
              let(:new_app) { AppModel.make(space: new_space) }
              let!(:service_instance_with_same_name_the_first_one) { ManagedServiceInstance.make(name: 'si-name', space: new_space) }
              let(:message) { AppManifestMessage.create_from_yml({ services: ['si-name'] }, {}) }

              it 'creates the binding in the correct space' do
                expect(ServiceInstance.where(name: 'si-name').count).to eq(2)
                expect(service_instance.space_guid).to_not eq(service_instance_with_same_name_the_first_one.space_guid)
                app_apply_manifest.apply(app.guid, message)
                expect(ServiceBindingCreate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
                expect(service_binding_create).to have_received(:create).
                  with(app, service_instance, instance_of(ServiceBindingCreateMessage), false, false)
              end
            end

            context 'when theres a service instance shared from another space' do
              let(:new_space) { Space.make }
              let!(:shared_si) { ManagedServiceInstance.make(name: 'shared-si', space: new_space) }
              let(:message) { AppManifestMessage.create_from_yml({ services: ['shared-si'] }, {}) }

              it 'creates the binding in the correct space' do
                shared_si.add_shared_space(space)

                app_apply_manifest.apply(app.guid, message)
                expect(ServiceBindingCreate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
                expect(service_binding_create).to have_received(:create).
                  with(app, shared_si, instance_of(ServiceBindingCreateMessage), false, false)
              end
            end

            context 'volume_services_enabled' do
              let(:message) { AppManifestMessage.create_from_yml({ services: ['si-name'] }, {}) }
              before do
                TestConfig.override(volume_services_enabled: true)
              end

              it 'passes the volume_services_enabled_flag to ServiceBindingCreate' do
                app_apply_manifest.apply(app.guid, message)
                expect(service_binding_create).to have_received(:create).
                  with(app, service_instance, instance_of(ServiceBindingCreateMessage), true, false)
              end
            end
          end

          context 'valid request with services that have parameters' do
            let(:message) { AppManifestMessage.create_from_yml({ services: [
              'name' => 'si-name',
              'parameters' => {
                'gud' => 'service'
              }
            ] },
            {})
            }
            let!(:service_instance) { ManagedServiceInstance.make(name: 'si-name', space: space) }
            let(:service_binding_create_message) { instance_double(ServiceBindingCreateMessage) }

            before do
              allow(ServiceBindingCreateMessage).to receive(:new).and_return(service_binding_create_message)
            end

            it 'calls ServiceBindingCreate with the correct arguments' do
              app_apply_manifest.apply(app.guid, message)
              expect(ServiceBindingCreate).to have_received(:new).with(user_audit_info, manifest_triggered: true)
              expect(ServiceBindingCreateMessage).to have_received(:new).with(
                type: AppApplyManifest::SERVICE_BINDING_TYPE,
                data: { parameters: { gud: 'service' } }
              )
              expect(service_binding_create).to have_received(:create).
                with(app, service_instance, service_binding_create_message, false, false)
            end
          end
        end

        describe 'when the app no longer exists' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', instances: 4 }, {}) }
          let(:app_guid) { 'fake-guid' }
          it 'raises a NotFound error' do
            expect {
              app_apply_manifest.apply(app_guid, message)
            }.to raise_error(CloudController::Errors::NotFound, "App with guid '#{app_guid}' not found")
          end
        end
      end
    end

    context 'when we want to test manifest mechanisms' do
      subject(:app_apply_manifest) { AppApplyManifest.new(user_audit_info) }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'x@y.com', user_guid: 'hi guid') }

      describe '#apply' do
        context 'when changing memory' do
          let(:message) { AppManifestMessage.create_from_yml({ name: 'blah', memory: '256MB' }, {}) }
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
