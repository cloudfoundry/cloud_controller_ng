require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe AppUsageEventPresenter do
    subject { described_class.new }

    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_key' => 'relationship_value' } }

    describe '#entity_hash' do
      let(:app_usage_event) { VCAP::CloudController::AppUsageEvent.make }

      before do
        app_usage_event.buildpack_name = 'some-buildpack'
        app_usage_event.process_type   = 'foobar'
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      it 'returns the app_usage_event entity and associated urls' do
        expect(subject.entity_hash(controller, app_usage_event, opts, depth, parents, orphans)).to eq(
          {
            'state'                              => app_usage_event.state,
            'previous_state'                     => app_usage_event.previous_state,
            'memory_in_mb_per_instance'          => app_usage_event.memory_in_mb_per_instance,
            'previous_memory_in_mb_per_instance' => app_usage_event.previous_memory_in_mb_per_instance,
            'instance_count'                     => app_usage_event.instance_count,
            'previous_instance_count'            => app_usage_event.previous_instance_count,
            'app_guid'                           => app_usage_event.app_guid,
            'app_name'                           => app_usage_event.app_name,
            'space_guid'                         => app_usage_event.space_guid,
            'space_name'                         => app_usage_event.space_name,
            'org_guid'                           => app_usage_event.org_guid,
            'buildpack_guid'                     => app_usage_event.buildpack_guid,
            'buildpack_name'                     => 'some-buildpack',
            'package_state'                      => app_usage_event.package_state,
            'previous_package_state'             => app_usage_event.previous_package_state,
            'parent_app_guid'                    => app_usage_event.parent_app_guid,
            'parent_app_name'                    => app_usage_event.parent_app_name,
            'process_type'                       => 'foobar',
            'task_name'                          => app_usage_event.task_name,
            'task_guid'                          => app_usage_event.task_guid,
            'relationship_key'                   => 'relationship_value'
          }
        )

        expect(relations_presenter).to have_received(:to_hash).with(controller, app_usage_event, opts, depth, parents, orphans)
      end

      context 'when buildpack urls contain user credentials' do
        before do
          app_usage_event.buildpack_name = 'https://secret:buildpack@example.com'
        end

        it 'obfuscates the credentials' do
          expect(subject.entity_hash(controller, app_usage_event, opts, depth, parents, orphans)).to eq(
            {
              'state'                              => app_usage_event.state,
              'previous_state'                     => app_usage_event.previous_state,
              'memory_in_mb_per_instance'          => app_usage_event.memory_in_mb_per_instance,
              'previous_memory_in_mb_per_instance' => app_usage_event.previous_memory_in_mb_per_instance,
              'instance_count'                     => app_usage_event.instance_count,
              'previous_instance_count'            => app_usage_event.previous_instance_count,
              'app_guid'                           => app_usage_event.app_guid,
              'app_name'                           => app_usage_event.app_name,
              'space_guid'                         => app_usage_event.space_guid,
              'space_name'                         => app_usage_event.space_name,
              'org_guid'                           => app_usage_event.org_guid,
              'buildpack_guid'                     => app_usage_event.buildpack_guid,
              'buildpack_name'                     => 'https://***:***@example.com',
              'package_state'                      => app_usage_event.package_state,
              'previous_package_state'             => app_usage_event.previous_package_state,
              'parent_app_guid'                    => app_usage_event.parent_app_guid,
              'parent_app_name'                    => app_usage_event.parent_app_name,
              'process_type'                       => app_usage_event.process_type,
              'task_name'                          => app_usage_event.task_name,
              'task_guid'                          => app_usage_event.task_guid,
              'relationship_key'                   => 'relationship_value'
            }
          )

          expect(relations_presenter).to have_received(:to_hash).with(controller, app_usage_event, opts, depth, parents, orphans)
        end
      end
    end
  end
end
