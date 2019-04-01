require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ServicePresenter do
    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_url' => 'http://relationship.example.com' } }
    subject { ServicePresenter.new }

    describe '#entity_hash' do
      before do
        set_current_user_as_admin
      end

      let(:volume_mount) { [{ 'container_dir' => 'mount' }] }
      let(:service_broker) { VCAP::CloudController::ServiceBroker.make(name: 'broker-1') }
      let(:service) do
        VCAP::CloudController::Service.make(service_broker: service_broker)
      end

      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      it 'returns the service binding entity' do
        expect(subject.entity_hash(controller, service, opts, depth, parents, orphans)).to eq(
          {
            'label'                 => service.label,
            'provider'              => service.provider,
            'url'                   => service.url,
            'description'           => service.description,
            'long_description'      => service.long_description,
            'version'               => service.version,
            'info_url'              => service.info_url,
            'active'                => service.active,
            'bindable'              => service.bindable,
            'unique_id'             => service.unique_id,
            'extra'                 => service.extra,
            'tags'                  => service.tags,
            'requires'              => service.requires,
            'documentation_url'     => service.documentation_url,
            'service_broker_guid'   => service.service_broker_guid,
            'service_broker_name'   => service.service_broker.name,
            'plan_updateable'       => service.plan_updateable,
            'bindings_retrievable'  => service.bindings_retrievable,
            'instances_retrievable' => service.instances_retrievable,
            'allow_context_updates' => service.allow_context_updates,
            'relationship_url'      => 'http://relationship.example.com'
          }
        )
      end

      context 'when the service broker is nil' do
        let(:service_broker) { nil }

        it 'returns the service binding entity' do
          expect(subject.entity_hash(controller, service, opts, depth, parents, orphans)).to eq(
            {
              'label'                 => service.label,
              'provider'              => service.provider,
              'url'                   => service.url,
              'description'           => service.description,
              'long_description'      => service.long_description,
              'version'               => service.version,
              'info_url'              => service.info_url,
              'active'                => service.active,
              'bindable'              => service.bindable,
              'unique_id'             => service.unique_id,
              'extra'                 => service.extra,
              'tags'                  => service.tags,
              'requires'              => service.requires,
              'documentation_url'     => service.documentation_url,
              'service_broker_guid'   => nil,
              'service_broker_name'   => nil,
              'plan_updateable'       => service.plan_updateable,
              'bindings_retrievable'  => service.bindings_retrievable,
              'instances_retrievable' => service.instances_retrievable,
              'allow_context_updates' => service.allow_context_updates,
              'relationship_url'      => 'http://relationship.example.com'
            }
          )
        end
      end
    end
  end
end
