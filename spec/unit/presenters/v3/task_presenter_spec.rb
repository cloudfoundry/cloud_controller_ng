require 'spec_helper'
require 'presenters/v3/task_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe TaskPresenter do
    subject(:presenter) { TaskPresenter.new(task) }
    let(:task_user) { nil }
    let(:task) do
      task = VCAP::CloudController::TaskModel.make(
        failure_reason: 'sup dawg',
        user: task_user,
        memory_in_mb: 2048,
        disk_in_mb: 4048,
        log_rate_limit: 1024,
        created_at: Time.at(1),
        sequence_id: 5
      )
      task.this.update(updated_at: Time.at(2))
      task.reload
    end

    let!(:release_label) do
      VCAP::CloudController::TaskLabelModel.make(
        key_name: 'release',
        value: 'stable',
        resource_guid: task.guid
      )
    end
    let!(:potato_label) do
      VCAP::CloudController::TaskLabelModel.make(
        key_prefix: 'canberra.au',
        key_name: 'potato',
        value: 'mashed',
        resource_guid: task.guid
      )
    end
    let!(:mountain_annotation) do
      VCAP::CloudController::TaskAnnotationModel.make(
        key_name: 'altitude',
        value: '14,412',
        resource_guid: task.guid
      )
    end
    let!(:plain_annotation) do
      VCAP::CloudController::TaskAnnotationModel.make(
        key_name: 'maize',
        value: 'hfcs',
        resource_guid: task.guid
      )
    end

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the task as a hash' do
        links = {
          self: { href: "#{link_prefix}/v3/tasks/#{task.guid}" },
          app: { href: "#{link_prefix}/v3/apps/#{task.app.guid}" },
          cancel: { href: "#{link_prefix}/v3/tasks/#{task.guid}/actions/cancel", method: 'POST' },
          droplet: { href: "#{link_prefix}/v3/droplets/#{task.droplet.guid}" }
        }

        expect(result[:guid]).to eq(task.guid)
        expect(result[:name]).to eq(task.name)
        expect(result[:command]).to eq(task.command)
        expect(result[:user]).to eq(task.run_action_user)
        expect(result[:state]).to eq(task.state)
        expect(result[:result][:failure_reason]).to eq 'sup dawg'
        expect(result[:memory_in_mb]).to eq(task.memory_in_mb)
        expect(result[:disk_in_mb]).to eq(task.disk_in_mb)
        expect(result[:log_rate_limit_in_bytes_per_second]).to eq(task.log_rate_limit)
        expect(result[:sequence_id]).to eq(5)
        expect(result[:created_at]).to eq(task.created_at.iso8601)
        expect(result[:updated_at]).to eq(task.updated_at.iso8601)
        expect(result[:relationships][:app][:data][:guid]).to eq(task.app_guid)
        expect(result[:metadata][:labels]).to eq('release' => 'stable', 'canberra.au/potato' => 'mashed')
        expect(result[:metadata][:annotations]).to eq('altitude' => '14,412', 'maize' => 'hfcs')
        expect(result[:links]).to eq(links)
      end

      context 'when show_secrets is false' do
        let(:presenter) { TaskPresenter.new(task, show_secrets: false) }

        it 'excludes command' do
          expect(result).not_to have_key(:command)
        end
      end

      describe 'user' do
        context 'when the droplet for the task has been deleted' do
          before do
            task.droplet.delete
            task.reload
          end

          it 'returns the user as nil' do
            expect(result[:user]).to be_nil
          end

          context 'when the task has an explicit user set' do
            let(:task_user) { 'TestUser' }

            it 'returns the user' do
              expect(result[:user]).to eq('TestUser')
            end
          end
        end
      end
    end
  end
end
