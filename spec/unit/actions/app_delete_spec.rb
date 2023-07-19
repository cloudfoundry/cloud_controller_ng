require 'spec_helper'
require 'actions/app_delete'

module VCAP::CloudController
  RSpec.describe AppDelete do
    subject(:app_delete) { AppDelete.new(user_audit_info) }
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }

    let!(:app) { AppModel.make }
    let!(:app_dataset) { [app] }

    describe '#delete' do
      it 'deletes the app record' do
        expect {
          app_delete.delete(app_dataset)
        }.to change { AppModel.count }.by(-1)
        expect(app.exists?).to be_falsey
      end

      context 'when the app no longer exists' do
        before do
          app.destroy
        end

        it 'throws an exception' do
          expect {
            app_delete.delete(app_dataset)
          }.to raise_error(Sequel::NoExistingObject, 'Record not found')
        end
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_delete_request).with(
          app,
          app.space,
          user_audit_info
        )

        app_delete.delete(app_dataset)
      end

      describe 'recursive deletion' do
        it 'deletes associated packages' do
          package = PackageModel.make(app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { PackageModel.count }.by(-1)
          expect(package.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated builds' do
          build = BuildModel.make(app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { BuildModel.count }.by(-1)
          expect(build.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        context 'when the builds have metadata' do
          let(:old_labels) do
            {
              fruit: 'pears',
              truck: 'hino'
            }
          end
          let(:old_annotations) do
            {
              potato: 'celandine',
              beet: 'formanova',
            }
          end
          let(:build) { BuildModel.make(app: app) }

          before do
            LabelsUpdate.update(build, old_labels, BuildLabelModel)
            AnnotationsUpdate.update(build, old_annotations, BuildAnnotationModel)
          end

          it 'deletes associated builds and metadata' do
            befores = [BuildLabelModel.count, BuildAnnotationModel.count]
            app_delete.delete(app_dataset)
            afters = [BuildLabelModel.count, BuildAnnotationModel.count]
            expect(build.exists?).to be_falsey
            expect(app.exists?).to be_falsey
            expect(befores - afters).to eq([2, 2])
          end
        end

        it 'deletes associated droplets' do
          droplet = DropletModel.make(app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { DropletModel.count }.by(-1)
          expect(droplet.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated processes' do
          process = ProcessModel.make(app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { ProcessModel.count }.by(-1)
          expect(process.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated sidecars' do
          sidecar = SidecarModel.make(app: app)
          sidecar_process_type = SidecarProcessTypeModel.make(sidecar: sidecar)

          expect {
            app_delete.delete(app_dataset)
          }.to change { SidecarModel.count }.by(-1)
          expect(sidecar.exists?).to be_falsey
          expect(sidecar_process_type.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated deployments' do
          deployment = DeploymentModel.make(app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { DeploymentModel.count }.by(-1)
          expect(deployment.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated labels' do
          label = AppLabelModel.make(app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { AppLabelModel.count }.by(-1)
          expect(label.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated annotations' do
          annotation = AppAnnotationModel.make(app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { AppAnnotationModel.count }.by(-1)
          expect(annotation.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        describe 'deleting associated routes' do
          let(:process_type) { 'web' }
          let(:process) { ProcessModel.make(app: app, type: process_type) }
          let(:route) { Route.make }
          let!(:route_mapping) { RouteMappingModel.make(app: app, route: route, process_type: process_type, app_port: 8080) }

          it 'deletes associated route mappings' do
            expect {
              app_delete.delete(app_dataset)
            }.to change { RouteMappingModel.count }.by(-1)
            expect(route_mapping.exists?).to be_falsey
            expect(app.exists?).to be_falsey
          end

          context 'when copilot is enabled', isolation: :truncation do
            let(:copilot_client) { instance_double(Cloudfoundry::Copilot::Client, unmap_route: nil, delete_capi_diego_process_association: nil) }
            let(:route) { Route.make(domain: istio_domain) }
            let(:istio_domain) { SharedDomain.make(name: 'istio.example.com') }

            before do
              TestConfig.override(copilot: { enabled: true, temporary_istio_domains: ['istio.example.com'] })
              allow_any_instance_of(Diego::Messenger).to receive(:send_stop_app_request)
              allow(CloudController::DependencyLocator.instance).to receive(:copilot_client).and_return(copilot_client)
            end

            it 'tells copilot to unmap the route' do
              expect(copilot_client).to receive(:unmap_route).with({ capi_process_guid: process.guid, route_guid: route.guid, route_weight: 1 })
              app_delete.delete(app_dataset)
            end

            it 'tells copilot to delete the capi process' do
              expect(copilot_client).to receive(:delete_capi_diego_process_association).with({ capi_process_guid: process.guid })
              app_delete.delete(app_dataset)
            end
          end
        end

        it 'deletes associated tasks' do
          task_model = TaskModel.make(app: app, name: 'task1', state: TaskModel::SUCCEEDED_STATE)

          expect {
            app_delete.delete(app_dataset)
          }.to change { TaskModel.count }.by(-1)
          expect(task_model.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated revisions' do
          revision = RevisionModel.make(app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { RevisionModel.count }.by(-1)
          expect(revision.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes the buildpack caches' do
          delete_buildpack_cache_jobs = Delayed::Job.where(Sequel.lit("handler like '%BuildpackCacheDelete%'"))
          expect { app_delete.delete(app_dataset) }.to change { delete_buildpack_cache_jobs.count }.by(1)
          job = delete_buildpack_cache_jobs.last

          expect(job.handler).to include(app.guid)
          expect(job.queue).to eq(Jobs::Queues.generic)
          expect(app.exists?).to be_falsey
        end

        it 'deletes the associated sidecars' do
          sidecar = SidecarModel.make(name: 'name', app: app)

          expect {
            app_delete.delete(app_dataset)
          }.to change { SidecarModel.count }.by(-1)
          expect(sidecar.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        describe 'deleting service bindings' do
          it 'deletes associated service bindings' do
            allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::Client).to receive(:unbind).and_return({ async: false })

            binding = ServiceBinding.make(app: app, service_instance: ManagedServiceInstance.make(space: app.space))

            expect {
              app_delete.delete(app_dataset)
            }.to change { ServiceBinding.count }.by(-1)
            expect(binding.exists?).to be_falsey
            expect(app.exists?).to be_falsey
          end

          context 'when service binding delete occurs asynchronously' do
            let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

            before do
              allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
              allow(client).to receive(:unbind).and_return({ async: true })
            end

            context 'with a single service binding' do
              let!(:binding1) { ServiceBinding.make(app: app, service_instance: ManagedServiceInstance.make(space: app.space)) }

              it 'should always call the broker with accepts_incomplete true' do
                expect(client).to receive(:unbind).with(binding1, user_guid: user_audit_info.user_guid, accepts_incomplete: true)

                expect { app_delete.delete(app_dataset) }.to raise_error(AppDelete::SubResourceError)
              end

              it 'return an error that a service binding is being deleted asynchronously' do
                expect { app_delete.delete(app_dataset) }.to raise_error(AppDelete::SubResourceError) do |err|
                  expect(err.underlying_errors.map(&:message)).to contain_exactly(
                    "An operation for the service binding between app #{binding1.app.name} and service instance #{binding1.service_instance.name} is in progress."
                  )
                end
              end

              it 'should not delete the app' do
                expect { app_delete.delete(app_dataset) }.to raise_error(AppDelete::SubResourceError)
                expect(binding1.exists?).to be_truthy
                expect(app.exists?).to be_truthy
              end

              it 'should not rollback the enqueuing of a job to delete the service binding' do
                expect { app_delete.delete(app_dataset) }.to raise_error(AppDelete::SubResourceError)
                expect(Delayed::Job.count).to eq 1
              end
            end

            context 'with multiple service bindings' do
              let!(:binding1) { ServiceBinding.make(app: app, service_instance: ManagedServiceInstance.make(space: app.space)) }
              let!(:binding2) { ServiceBinding.make(app: app, service_instance: ManagedServiceInstance.make(space: app.space)) }

              it 'returns some errors describing that the service bindings are being deleted asynchronously' do
                expect { app_delete.delete(app_dataset) }.to raise_error(AppDelete::SubResourceError) do |err|
                  expect(err.underlying_errors.map(&:message)).to contain_exactly(
                    "An operation for the service binding between app #{binding2.app.name} and service instance #{binding2.service_instance.name} is in progress.",
                        "An operation for the service binding between app #{binding1.app.name} and service instance #{binding1.service_instance.name} is in progress."
                  )
                end
              end
            end
          end

          context 'when service binding delete returns errors' do
            let!(:binding1) { ServiceBinding.make(app: app, service_instance: ManagedServiceInstance.make(space: app.space)) }
            let!(:binding2) { ServiceBinding.make(app: app, service_instance: ManagedServiceInstance.make(space: app.space)) }

            before do
              binding_delete_action = V3::ServiceCredentialBindingDelete
              call_number = 0
              allow_any_instance_of(binding_delete_action).to receive(:delete) do
                call_number += 1
                raise StandardError.new("error #{call_number}")
              end
            end

            it 'raises the errors wrapped into a SubResourceError' do
              expect {
                app_delete.delete(app_dataset)
              }.to raise_error(AppDelete::SubResourceError) do |err|
                expect(err.underlying_errors).to have(2).items
                expect(err.underlying_errors).to all(be_a(StandardError))
                expect(err.underlying_errors.map(&:message)).to eq(['error 1', 'error 2'])
              end
            end
          end
        end
      end
    end

    describe '#delete_without_event' do
      it 'deletes the app record' do
        expect {
          app_delete.delete_without_event(app_dataset)
        }.to change { AppModel.count }.by(-1)
        expect(app.exists?).to be_falsey
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).not_to receive(:record_app_delete_request)
        app_delete.delete_without_event(app_dataset)
      end
    end
  end
end
