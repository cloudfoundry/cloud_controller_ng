require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe BasePresenter do
    subject { described_class.new }
    let(:controller) { double(:controller, url_for_guid: 'controller-url') }
    let(:obj) { double(:obj, guid: 'obj-guid', created_at: 'obj-created-at', updated_at: 'obj-updated-at') }
    let(:opts) { 'opts' }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }

    describe '#to_hash' do
      it 'raises NotImplementedError' do
        expect { subject.to_hash(controller, obj, opts, depth, parents, orphans) }.to raise_error(NotImplementedError)
      end
    end

    describe 'subclass that implements entity_hash' do
      class TestPresenter < BasePresenter
        def entity_hash(controller, obj, opts, depth, parents, orphans)
          {
            'controller' => controller,
            'obj'        => obj,
            'opts'       => opts,
            'depth'      => depth,
            'parents'    => parents,
            'orphans'    => orphans,
          }
        end
      end

      subject { TestPresenter.new }

      it 'creates the correct metadata key' do
        response = subject.to_hash(controller, obj, opts, depth, parents, orphans)

        expect(response['metadata']).to eq(
          {
            'guid'       => 'obj-guid',
            'url'        => 'controller-url',
            'created_at' => 'obj-created-at',
            'updated_at' => 'obj-updated-at'
          }
        )

        expect(controller).to have_received(:url_for_guid).with('obj-guid')
      end

      context 'when the object does not respond to updated_at' do
        let(:obj) { double(:obj, guid: 'obj-guid', created_at: 'obj-created-at') }

        it 'excludes updated_at' do
          response = subject.to_hash(controller, obj, opts, depth, parents, orphans)

          expect(response['metadata']).not_to have_key('updated_at')
        end
      end

      it 'passes the correct values to entity_hash' do
        response = subject.to_hash(controller, obj, opts, depth, parents, orphans)

        expect(response['entity']).to eq(
          {
            'controller' => controller,
            'obj'        => obj,
            'opts'       => opts,
            'depth'      => depth,
            'parents'    => parents,
            'orphans'    => orphans,
          }
        )

        expect(controller).to have_received(:url_for_guid).with('obj-guid')
      end
    end
  end
end
