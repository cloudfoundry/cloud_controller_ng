require 'spec_helper'

module VCAP::CloudController
  RSpec.describe CNBLifecycleDataModel do
    subject(:lifecycle_data) { CNBLifecycleDataModel.make([]) }

    describe '#stack' do
      it 'persists the stack' do
        lifecycle_data.stack = 'cflinuxfs4'
        lifecycle_data.save
        expect(lifecycle_data.reload.stack).to eq 'cflinuxfs4'
      end
    end

    describe '#buildpacks' do
      before do
        Buildpack.make(name: 'another-buildpack')
        Buildpack.make(name: 'new-buildpack')
        Buildpack.make(name: 'ruby')
        Buildpack.make(name: 'some-buildpack')
      end

      context 'when passed in nil' do
        it 'does not persist any buildpacks' do
          lifecycle_data.buildpacks = nil
          lifecycle_data.save
          expect(lifecycle_data.reload.buildpacks).to eq []
        end
      end

      context 'when using a buildpack URL' do
        it 'persists the buildpack and reads it back' do
          lifecycle_data.buildpacks = ['http://buildpack.example.com']
          lifecycle_data.save
          expect(lifecycle_data.reload.buildpacks).to eq ['http://buildpack.example.com']
        end

        it 'persists multiple buildpacks and reads them back' do
          lifecycle_data.buildpacks = ['http://buildpack-1.example.com', 'http://buildpack-2.example.com']
          lifecycle_data.save
          expect(lifecycle_data.reload.buildpacks).to eq ['http://buildpack-1.example.com', 'http://buildpack-2.example.com']
        end

        context 'when the lifecycle already contains a list of buildpacks' do
          subject(:lifecycle_data) do
            BuildpackLifecycleDataModel.create(buildpacks: ['http://original-buildpack-1.example.com', 'http://original-buildpack-2.example.com'])
          end

          it 'overrides the list of buildpacks and reads it back' do
            expect(lifecycle_data.buildpacks).to eq ['http://original-buildpack-1.example.com', 'http://original-buildpack-2.example.com']

            lifecycle_data.buildpacks = ['http://new-buildpack.example.com']
            lifecycle_data.save
            expect(lifecycle_data.reload.buildpacks).to eq ['http://new-buildpack.example.com']
          end

          it 'deletes the buildpacks when the lifecycle is deleted' do
            lifecycle_data_guid = lifecycle_data.guid
            expect(lifecycle_data_guid).not_to be_nil
            expect(BuildpackLifecycleBuildpackModel.where(buildpack_lifecycle_data_guid: lifecycle_data_guid)).not_to be_empty

            lifecycle_data.destroy
            expect(BuildpackLifecycleBuildpackModel.where(buildpack_lifecycle_data_guid: lifecycle_data_guid)).to be_empty
          end
        end

        context 'when using only buildpack url' do
          it 'persists the buildpacks and reads them back' do
            lifecycle_data.buildpacks = ['http://foo:bar@buildpackurl.com']
            lifecycle_data.save
            expect(lifecycle_data.reload.buildpacks).to eq ['http://foo:bar@buildpackurl.com']
            expect(lifecycle_data.reload.buildpack_lifecycle_buildpacks.map(&:buildpack_url)).to eq ['http://foo:bar@buildpackurl.com']
            expect(lifecycle_data.reload.buildpack_lifecycle_buildpacks.map(&:admin_buildpack_name)).to eq [nil]
          end
        end
      end
    end

    describe '#buildpack_models' do
      context 'when the buildpacks are only custom buildpacks' do
        let(:buildpack1_url) { 'http://example.com/buildpack1' }
        let(:buildpack2_url) { 'http://example.com/buildpack2' }

        before do
          lifecycle_data.buildpacks = [buildpack1_url, buildpack2_url]
        end

        it 'returns an array of corresponding buildpack objects' do
          expect(lifecycle_data.buildpack_models).to eq([CustomBuildpack.new(buildpack1_url),
                                                         CustomBuildpack.new(buildpack2_url)])
        end
      end
    end

    describe '#using_custom_buildpack?' do
      context 'when using a custom buildpack' do
        context 'when using multiple buildpacks' do
          subject(:lifecycle_data) do
            BuildpackLifecycleDataModel.new(buildpacks: ['https://github.com/buildpacks/the-best', 'gcr.io/paketo-buildpacks/nodejs'])
          end

          it 'returns true' do
            expect(lifecycle_data.using_custom_buildpack?).to be true
          end
        end
      end

      context 'when not using a custom buildpack' do
        subject(:lifecycle_data) { BuildpackLifecycleDataModel.new(buildpacks: nil) }

        it 'returns false' do
          expect(lifecycle_data.using_custom_buildpack?).to be false
        end
      end
    end

    describe '#first_custom_buildpack_url' do
      context 'when using a single-instance legacy buildpack' do
        subject(:lifecycle_data) { BuildpackLifecycleDataModel.new }

        it 'returns the first url' do
          lifecycle_data.legacy_buildpack_url = 'https://someurl.com'
          expect(lifecycle_data.first_custom_buildpack_url).to eq 'https://someurl.com'
        end
      end

      context 'when using multiple buildpacks' do
        context 'and there are custom buildpacks' do
          subject(:lifecycle_data) do
            BuildpackLifecycleDataModel.new(buildpacks: ['ruby', 'https://github.com/buildpacks/the-best'])
          end

          it 'returns the first url' do
            expect(lifecycle_data.first_custom_buildpack_url).to eq 'https://github.com/buildpacks/the-best'
          end
        end

        context 'and there are not any custom buildpacks' do
          subject(:lifecycle_data) do
            BuildpackLifecycleDataModel.new(buildpacks: %w[ruby java])
          end

          it 'returns nil' do
            expect(lifecycle_data.first_custom_buildpack_url).to be_nil
          end
        end
      end
    end

    describe '#to_hash' do
      let(:expected_lifecycle_data) do
        { buildpacks: buildpacks || [], stack: 'cflinuxfs4' }
      end
      let(:buildpacks) { [buildpack] }
      let(:buildpack) { 'http://gcr.io/paketo-buildpacks/nodejs' }
      let(:stack) { 'cflinuxfs4' }

      before do
        lifecycle_data.stack = stack
        lifecycle_data.buildpacks = buildpacks
        lifecycle_data.save
      end

      it 'returns the lifecycle data as a hash' do
        expect(lifecycle_data.to_hash).to eq expected_lifecycle_data
      end

      context 'when the user has not specified a buildpack' do
        let(:buildpacks) { nil }

        it 'returns the lifecycle data as a hash' do
          expect(lifecycle_data.to_hash).to eq expected_lifecycle_data
        end
      end

      context 'when the buildpack is an url' do
        let(:buildpack) { 'https://github.com/puppychutes' }

        it 'returns the lifecycle data as a hash' do
          expect(lifecycle_data.to_hash).to eq expected_lifecycle_data
        end

        it 'calls out to UrlSecretObfuscator' do
          allow(CloudController::UrlSecretObfuscator).to receive(:obfuscate)

          lifecycle_data.to_hash

          expect(CloudController::UrlSecretObfuscator).to have_received(:obfuscate).exactly :once
        end
      end
    end

    describe '#valid?' do
      it 'cannot be associated with both an app and a build' do
        build = BuildModel.make
        app = AppModel.make
        lifecycle_data.build = build
        lifecycle_data.app = app
        expect(lifecycle_data.valid?).to be(false)
        expect(lifecycle_data.errors.full_messages.first).to include('Must be associated with an app OR a build+droplet, but not both')
      end

      it 'cannot be associated with both an app and a droplet' do
        droplet = DropletModel.make
        app = AppModel.make
        lifecycle_data.droplet = droplet
        lifecycle_data.app = app
        expect(lifecycle_data.valid?).to be(false)
        expect(lifecycle_data.errors.full_messages.first).to include('Must be associated with an app OR a build+droplet, but not both')
      end

      it 'cannot contain invalid buildpacks' do
        app = AppModel.make
        lifecycle_data.app = app
        lifecycle_data.buildpacks = [nil, nil]
        expect(lifecycle_data.valid?).to be(false)
        expect(lifecycle_data.errors.full_messages.size).to eq(2)
        expect(lifecycle_data.errors.full_messages.first).to include('Must specify either a buildpack_url or an admin_buildpack_name')
      end

      it 'adds CNBLifecyleBuildpack errors to the BuildpackLifecycleBuildpacksDataModels' do
        app = AppModel.make
        lifecycle_data.app = app
        lifecycle_data.buildpacks = ['https://example.com', 'invalid_buildpack_name']
        lifecycle_data.buildpack_lifecycle_buildpacks.each { |b| b.cnb_lifecycle_data = lifecycle_data }

        expect(lifecycle_data.valid?).to be(false)
        expect(lifecycle_data.errors.full_messages.size).to eq(1)
        expect(lifecycle_data.errors.full_messages.first).to include('Specified invalid buildpack URL: "invalid_buildpack_name"')
      end

      it 'is valid' do
        app = AppModel.make
        lifecycle_data.app = app
        lifecycle_data.buildpacks = ['docker://gcr.io/acme', 'https://example.com']
        expect(lifecycle_data.valid?).to be(true)
      end
    end

    describe 'associations' do
      it 'can be associated with a droplet' do
        droplet = DropletModel.make
        lifecycle_data.droplet = droplet
        lifecycle_data.save
        expect(lifecycle_data.reload.droplet).to eq(droplet)
      end

      it 'can be associated with apps' do
        app = AppModel.make
        lifecycle_data.app = app
        lifecycle_data.save
        expect(lifecycle_data.reload.app).to eq(app)
      end

      it 'can be associated with a build' do
        build = BuildModel.make
        lifecycle_data.build = build
        lifecycle_data.save
        expect(lifecycle_data.reload.build).to eq(build)
      end
    end
  end
end
