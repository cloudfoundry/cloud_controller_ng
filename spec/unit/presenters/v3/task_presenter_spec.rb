require 'spec_helper'
require 'presenters/v3/task_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe TaskPresenter do
    subject(:presenter) { TaskPresenter.new(task) }
    let(:task) {
      task = VCAP::CloudController::TaskModel.make(
        failure_reason: 'sup dawg',
        memory_in_mb:   2048,
        disk_in_mb:     4048,
        created_at:     Time.at(1),
        sequence_id:    5
      )
      task.this.update(updated_at: Time.at(2))
      task.reload
    }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the task as a hash' do
        links = {
          self:    { href: "#{link_prefix}/v3/tasks/#{task.guid}" },
          app:     { href: "#{link_prefix}/v3/apps/#{task.app.guid}" },
          cancel:  { href: "#{link_prefix}/v3/tasks/#{task.guid}/actions/cancel", method: 'POST' },
          droplet: { href: "#{link_prefix}/v3/droplets/#{task.droplet.guid}" },
        }

        expect(result[:guid]).to eq(task.guid)
        expect(result[:name]).to eq(task.name)
        expect(result[:command]).to eq(task.command)
        expect(result[:state]).to eq(task.state)
        expect(result[:result][:failure_reason]).to eq 'sup dawg'
        expect(result[:memory_in_mb]).to eq(task.memory_in_mb)
        expect(result[:disk_in_mb]).to eq(task.disk_in_mb)
        expect(result[:sequence_id]).to eq(5)
        expect(result[:created_at]).to eq(task.created_at.iso8601)
        expect(result[:updated_at]).to eq(task.updated_at.iso8601)
        expect(result[:links]).to eq(links)
      end

      context 'when show_secrets is false' do
        let(:presenter) { TaskPresenter.new(task, show_secrets: false) }

        it 'excludes command' do
          expect(result).not_to have_key(:command)
        end
      end
    end
  end
end
