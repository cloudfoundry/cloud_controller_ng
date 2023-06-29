require 'spec_helper'
require 'presenters/v3/stack_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::StackPresenter do
  let(:stack) do
    VCAP::CloudController::Stack.make(
      run_rootfs_image: 'run-image',
      build_rootfs_image: 'build-image',
    )
  end

  let!(:release_label) do
    VCAP::CloudController::StackLabelModel.make(
      key_name: 'release',
      value: 'stable',
      resource_guid: stack.guid
    )
  end

  let!(:potato_label) do
    VCAP::CloudController::StackLabelModel.make(
      key_prefix: 'canberra.au',
      key_name: 'potato',
      value: 'mashed',
      resource_guid: stack.guid
    )
  end

  let!(:mountain_annotation) do
    VCAP::CloudController::StackAnnotationModel.make(
      key: 'altitude',
      value: '14,412',
      resource_guid: stack.guid,
    )
  end

  let!(:plain_annotation) do
    VCAP::CloudController::StackAnnotationModel.make(
      key: 'maize',
      value: 'hfcs',
      resource_guid: stack.guid,
    )
  end

  describe '#to_hash' do
    let(:result) { described_class.new(stack).to_hash }

    context 'when optional fields are present' do
      it 'presents the stack with those fields' do
        expect(result[:guid]).to eq(stack.guid)
        expect(result[:created_at]).to eq(stack.created_at)
        expect(result[:updated_at]).to eq(stack.updated_at)
        expect(result[:name]).to eq(stack.name)
        expect(result[:description]).to eq(stack.description)
        expect(result[:run_rootfs_image]).to eq(stack.run_rootfs_image)
        expect(result[:build_rootfs_image]).to eq(stack.build_rootfs_image)
        expect(result[:default]).to eq(false)
        expect(result[:metadata][:labels]).to eq('release' => 'stable', 'canberra.au/potato' => 'mashed')
        expect(result[:metadata][:annotations]).to eq('altitude' => '14,412', 'maize' => 'hfcs')
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/stacks/#{stack.guid}")
      end
    end

    context 'when optional fields are missing' do
      before do
        stack.description = nil
        stack.run_rootfs_image = nil
        stack.build_rootfs_image = nil
      end

      it 'still presents their keys with nil values' do
        expect(result.fetch(:description)).to be_nil
      end

      it 'presents their fallback values' do
        expect(result.fetch(:run_rootfs_image)).to eq(stack.name)
        expect(result.fetch(:build_rootfs_image)).to eq(stack.name)
      end

      it 'still presents all other values' do
        expect(result[:guid]).to eq(stack.guid)
        expect(result[:created_at]).to eq(stack.created_at)
        expect(result[:updated_at]).to eq(stack.updated_at)
        expect(result[:name]).to eq(stack.name)
        expect(result[:default]).to eq(false)
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/stacks/#{stack.guid}")
      end
    end
  end
end
