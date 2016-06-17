require 'spec_helper'
require 'cloud_controller/diego/lifecycles/buildpack_info'

module VCAP::CloudController
  RSpec.describe BuildpackInfo do
    subject(:info) { BuildpackInfo.new(buildpack_name_or_url, buildpack_record) }

    let(:buildpack_name_or_url) { buildpack_record.name.upcase }
    let(:buildpack_record) { Buildpack.make }

    it 'returns the correct properties' do
      expect(info.buildpack).to eq(buildpack_name_or_url)
      expect(info.buildpack_record).to eq(buildpack_record)
      expect(info.buildpack_url).to eq(nil)
    end

    context 'when it is provided a buildpack url' do
      let(:buildpack_name_or_url) { 'http://totally.a.url' }
      let(:buildpack_record) { nil }

      it 'returns the correct properties' do
        expect(info.buildpack).to eq('http://totally.a.url')
        expect(info.buildpack_url).to eq('http://totally.a.url')
        expect(info.buildpack_record).to be_nil
      end
    end

    describe '#buildpack_exists_in_db?' do
      context 'when there is a record' do
        it 'is true' do
          expect(info.buildpack_exists_in_db?).to be_truthy
        end
      end

      context 'when there is NOT a record' do
        let(:buildpack_name_or_url) { 'potato' }
        let(:buildpack_record) { nil }

        it 'is false' do
          expect(info.buildpack_exists_in_db?).to be_falsey
        end
      end
    end

    describe '#to_s' do
      context 'when it is a url' do
        let(:buildpack_name_or_url) { 'http://totally.a.url' }
        let(:buildpack_record) { nil }

        it 'returns the url' do
          expect(info.to_s).to eq('http://totally.a.url')
        end
      end

      context 'when it is found in the database' do
        it 'returns the buildpack record name' do
          expect(info.to_s).to eq(buildpack_record.name)
        end
      end

      context 'when it is not found in the database and is not a url' do
        let(:buildpack_name_or_url) { 'BLARGAS' }
        let(:buildpack_record) { nil }

        it 'returns nil' do
          expect(info.to_s).to be_nil
        end
      end
    end
  end
end
