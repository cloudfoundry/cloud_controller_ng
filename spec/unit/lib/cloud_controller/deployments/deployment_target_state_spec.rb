require 'spec_helper'
require 'cloud_controller/deployments/deployment_target_state'

module VCAP::CloudController
  RSpec.describe DeploymentTargetState do
    subject(:target_state) { DeploymentTargetState.new(app, message) }
    let(:app) { AppModel.make(environment_variables: { 'foo' => 'bar' }) }
    let(:droplet) { DropletModel.make(app: app, process_types: { 'web' => 'command' }) }

    describe 'droplet' do
      context 'revision provided' do
        let(:revision) { RevisionModel.make(droplet: droplet) }
        let(:message) {
          DeploymentCreateMessage.new({
            relationships: { app: { data: { guid: app.guid } } },
            revision: { guid: revision.guid },
          })
        }

        context 'the revision exists' do
          it 'returns the droplet associated with the given revision' do
            expect(subject.droplet).to eq(revision.droplet)
          end

          context 'the droplet does NOT exist' do
            before do
              droplet.delete
            end

            it 'raises an error' do
              expect {
                subject.droplet
              }.to raise_error(DeploymentCreate::Error, /Unable to deploy this revision, the droplet for this revision no longer exists/)
            end
          end

          context 'the droplet is expired' do
            before do
              droplet.update(state: DropletModel::EXPIRED_STATE)
            end

            it 'raises an error' do
              expect {
                subject.droplet
              }.to raise_error(DeploymentCreate::Error, /Unable to deploy this revision, the droplet for this revision no longer exists/)
            end
          end
        end

        context 'the revision does NOT exist' do
          before do
            revision.destroy
          end

          it 'raises an error' do
            expect {
              subject.droplet
            }.to raise_error(DeploymentCreate::Error, /The revision does not exist/)
          end
        end
      end

      context 'droplet provided' do
        let(:message) {
          DeploymentCreateMessage.new({
            relationships: { app: { data: { guid: app.guid } } },
            droplet: { guid: droplet.guid },
          })
        }

        it 'returns the droplet' do
          expect(subject.droplet).to eq(droplet)
        end
      end

      context 'neither droplet or revision provided' do
        let(:message) {
          DeploymentCreateMessage.new({
            relationships: { app: { data: { guid: app.guid } } },
          })
        }

        context 'the app has a droplet set' do
          before do
            app.update(droplet: droplet)
          end

          it 'returns the droplet associated with the app' do
            expect(subject.droplet).to eq(app.droplet)
          end
        end

        context 'the app does not have a droplet set' do
          before do
            app.update(droplet: nil)
          end

          it 'raises an error' do
            expect {
              subject.droplet
            }.to raise_error(DeploymentCreate::Error, /Invalid droplet. Please specify a droplet in the request or set a current droplet for the app./)
          end
        end
      end
    end

    describe 'environment_variables' do
      context 'a revision is provided' do
        let(:revision) do
          RevisionModel.make(droplet: droplet, environment_variables: { 'baz' => 'qux' })
        end
        let(:message) {
          DeploymentCreateMessage.new({
            relationships: { app: { data: { guid: app.guid } } },
            revision: { guid: revision.guid },
          })
        }

        it 'returns the revision env vars' do
          expect(subject.environment_variables).to eq(revision.environment_variables)
        end
      end

      context 'a revision is NOT provided' do
        let(:message) {
          DeploymentCreateMessage.new({
            relationships: { app: { data: { guid: app.guid } } },
            droplet: { guid: droplet.guid },
          })
        }

        it 'returns the app env vars' do
          expect(subject.environment_variables).to eq(app.environment_variables)
        end
      end
    end

    describe 'rollback_target_revision' do
      context 'a revision is provided' do
        let(:revision) { RevisionModel.make(droplet: droplet) }
        let(:message) {
          DeploymentCreateMessage.new({
            relationships: { app: { data: { guid: app.guid } } },
            revision: { guid: revision.guid },
          })
        }

        it 'returns the given revision' do
          expect(subject.rollback_target_revision).to eq(revision)
        end
      end

      context 'a revision is not provided' do
        let(:message) {
          DeploymentCreateMessage.new({
            relationships: { app: { data: { guid: app.guid } } },
            droplet: { guid: droplet.guid },
          })
        }

        it 'returns nil' do
          expect(subject.rollback_target_revision).to be_nil
        end
      end
    end

    describe '#apply_to_app' do
      let(:user_audit_info) { UserAuditInfo.new(user_guid: '123', user_email: 'connor@example.com', user_name: 'braa') }
      let(:message) {
        DeploymentCreateMessage.new({
          relationships: { app: { data: { guid: app.guid } } },
          droplet: { guid: droplet.guid },
        })
      }

      context 'assigning the droplet succeeds' do
        it 'assigns the droplet to the app' do
          subject.apply_to_app(app, user_audit_info)

          expect(app.droplet).to eq(droplet)
        end
      end

      context 'assigning the droplet fails' do
        before do
          allow_any_instance_of(AppAssignDroplet).
            to receive(:assign).
            with(app, droplet).
            and_raise(AppAssignDroplet::Error.new('foo'))
        end

        it 'raises an error' do
          expect {
            subject.apply_to_app(app, user_audit_info)
          }.to raise_error(DeploymentCreate::Error, /foo/)
        end
      end

      context 'when rolling back to a revision' do
        let(:message) {
          DeploymentCreateMessage.new({
            relationships: { app: { data: { guid: app.guid } } },
            revision: { guid: revision.guid },
          })
        }
        let(:revision) { RevisionModel.make(droplet: droplet, app: app) }

        context 'assigning environment variables' do
          let(:revision) do
            RevisionModel.make(droplet: droplet, app: app, environment_variables: { 'baz' => 'qux' })
          end

          it 'assigns environment variables to the app' do
            subject.apply_to_app(app, user_audit_info)

            expect(app.environment_variables).to eq(revision.environment_variables)
          end
        end

        context 'assigning sidecars to the app' do
          let!(:revision_sidecar) do
            RevisionSidecarModel.make(
              revision: revision,
              name: 'sidecar-name',
              command: 'sidecar-command',
              memory: 12,
            )
          end

          it 'assigns the sidecar to the app' do
            subject.apply_to_app(app, user_audit_info)

            expect(app.reload.sidecars).to have(1).items
            expect(app.sidecars.first.name).to eq('sidecar-name')
            expect(app.sidecars.first.command).to eq('sidecar-command')
            expect(app.sidecars.first.memory).to eq(12)
            expect(app.sidecars.first.process_types).to eq(revision_sidecar.process_types)
          end
        end

        context 'removing sidecars from the app' do
          let!(:sidecar) { SidecarModel.make(app: app) }

          it 'removes the sidecars from the app' do
            subject.apply_to_app(app, user_audit_info)

            expect(app.reload.sidecars).to have(0).items
            expect(sidecar.exists?).to be_falsey
          end
        end
      end
    end
  end
end
