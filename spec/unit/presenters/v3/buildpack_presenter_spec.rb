require 'spec_helper'
require 'presenters/v3/buildpack_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::BuildpackPresenter do
  let(:buildpack) { VCAP::CloudController::Buildpack.make }

  describe '#to_hash' do
    let(:result) { described_class.new(buildpack).to_hash }

    describe 'links' do
      it 'has self and upload links' do
        expect(result[:links][:upload][:href]).to eq("#{link_prefix}/v3/buildpacks/#{buildpack.guid}/upload")
        expect(result[:links][:upload][:method]).to eq('POST')
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/buildpacks/#{buildpack.guid}")
      end
    end

    context 'when optional fields are present' do
      it 'presents the buildpack with those fields' do
        expect(result[:guid]).to eq(buildpack.guid)
        expect(result[:created_at]).to eq(buildpack.created_at)
        expect(result[:updated_at]).to eq(buildpack.updated_at)
        expect(result[:name]).to eq(buildpack.name)
        expect(result[:state]).to eq(buildpack.state)
        expect(result[:filename]).to eq(buildpack.filename)
        expect(result[:stack]).to eq(buildpack.stack)
        expect(result[:position]).to eq(buildpack.position)
        expect(result[:enabled]).to eq(buildpack.enabled)
        expect(result[:locked]).to eq(buildpack.locked)
      end
    end

    context 'when optional fields are missing' do
      before do
        buildpack.stack = nil
        buildpack.filename = nil
      end

      it 'still presents their keys with nil values' do
        expect(result.fetch(:stack)).to be_nil
      end

      it 'still presents all other values' do
        expect(result[:guid]).to eq(buildpack.guid)
        expect(result[:created_at]).to eq(buildpack.created_at)
        expect(result[:updated_at]).to eq(buildpack.updated_at)
        expect(result[:name]).to eq(buildpack.name)
        expect(result[:state]).to eq(buildpack.state)
        expect(result[:filename]).to eq(nil)
        expect(result[:position]).to eq(buildpack.position)
        expect(result[:enabled]).to eq(buildpack.enabled)
        expect(result[:locked]).to eq(buildpack.locked)
      end
    end
  end
end
