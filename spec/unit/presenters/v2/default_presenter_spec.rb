require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe DefaultPresenter do
    subject { described_class.new }

    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 0 }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:serializable_object) do
      Class.new do
        include Sequel::Plugins::VcapSerialization::InstanceMethods
        extend Sequel::Plugins::VcapSerialization::ClassMethods

        export_attributes :key1, :key2

        attr_accessor :key1, :key2

        def initialize
          @key1 = 'val1'
          @key2 = 'val2'
        end
      end.new
    end
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { {} }

    describe '#entity_hash' do
      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      it 'builds a hash using export_attributes of the object' do
        expect(subject.entity_hash(controller, serializable_object, opts, depth, parents, orphans)).
          to include({ 'key1' => 'val1', 'key2' => 'val2' })
      end

      context 'when the relations presenter provides data' do
        let(:relations_hash) { { 'mergeme' => 'bro' } }

        it 'merges in relations to the response hash' do
          expect(subject.entity_hash(controller, serializable_object, opts, depth, parents, orphans)).
            to include({ 'mergeme' => 'bro' })

          expect(relations_presenter).to have_received(:to_hash).with(controller, serializable_object, opts, depth, parents, orphans)
        end
      end

      context 'when export_attrs are requested in opts' do
        let(:opts) { { export_attrs: [:key2] } }

        context 'when depth is 0' do
          it 'whitelists the requested export_attrs in the response' do
            expect(subject.entity_hash(controller, serializable_object, opts, depth, parents, orphans)).to eq({ 'key2' => 'val2' })
          end
        end

        context 'when depth is not 0' do
          let(:depth) { 1 }

          it 'ignores requested export_attrs in favor of the model definitions' do
            expect(subject.entity_hash(controller, serializable_object, opts, depth, parents, orphans)).to eq({ 'key1' => 'val1', 'key2' => 'val2' })
          end
        end
      end

      context 'when the object class defines export_attributes_from_methods' do
        let(:serializable_object) do
          Class.new do
            include Sequel::Plugins::VcapSerialization::InstanceMethods
            extend Sequel::Plugins::VcapSerialization::ClassMethods

            export_attributes :key1, :key2
            export_attributes_from_methods key2: :houdini

            attr_accessor :key1, :key2

            def initialize
              @key1 = 'val1'
              @key2 = 'val2'
            end

            def houdini
              'surprise!'
            end
          end.new
        end

        it 'overrides the hash response with the result of the requested method' do
          expect(
            subject.entity_hash(controller, serializable_object, opts, depth, parents, orphans)
          ).to eq({ 'key1' => 'val1', 'key2' => 'surprise!' })
        end
      end
    end
  end
end
