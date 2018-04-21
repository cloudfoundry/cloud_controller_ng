require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataModel do
    subject(:lifecycle_data) { BuildpackLifecycleDataModel.new }

    it_behaves_like 'a model with an encrypted attribute' do
      let(:value_to_encrypt) { 'https://acme-buildpack.com' }
      let(:encrypted_attr) { :buildpack_url }
      let(:storage_column) { :encrypted_buildpack_url }
      let(:attr_salt) { :encrypted_buildpack_url_salt }
    end

    describe '#stack' do
      it 'persists the stack' do
        lifecycle_data.stack = 'cflinuxfs2'
        lifecycle_data.save
        expect(lifecycle_data.reload.stack).to eq 'cflinuxfs2'
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
            expect(lifecycle_data_guid).to_not be_nil
            expect(BuildpackLifecycleBuildpackModel.where(buildpack_lifecycle_data_guid: lifecycle_data_guid)).to_not be_empty

            lifecycle_data.destroy
            expect(BuildpackLifecycleBuildpackModel.where(buildpack_lifecycle_data_guid: lifecycle_data_guid)).to be_empty
          end
        end

        context 'when using a buildpack name' do
          it 'persists the buildpack and reads it back' do
            lifecycle_data.buildpacks = ['some-buildpack']
            lifecycle_data.save
            expect(lifecycle_data.reload.buildpacks).to eq ['some-buildpack']
            expect(lifecycle_data.reload.buildpack_lifecycle_buildpacks.map(&:admin_buildpack_name)).to eq ['some-buildpack']
          end

          it 'persists multiple buildpacks and reads them back' do
            lifecycle_data.buildpacks = ['some-buildpack', 'another-buildpack']
            lifecycle_data.save
            expect(lifecycle_data.reload.buildpacks).to eq ['some-buildpack', 'another-buildpack']
          end

          context 'multi-field buildpack-lifecycle-buildpacks' do
            let(:buildpack1_name) { 'pleasant-valley-buildpack' }
            let(:buildpack1_other_name) { 'valley' }
            let(:buildpack1_version) { '3.1' }
            let!(:buildpack1) { VCAP::CloudController::Buildpack.make(name: buildpack1_name, sha256_checksum: 'mammoth') }
            let(:buildpack2_name) { 'stepping-stone-buildpack' }
            let(:buildpack2_other_name) { 'gilooley' }
            let(:buildpack2_version) { '95' }
            let!(:buildpack2) { VCAP::CloudController::Buildpack.make(name: buildpack2_name, sha256_checksum: 'languid') }

            let(:lifecycle_buildpacks) do
              [
                {
                  name: buildpack1_other_name,
                  version: buildpack1_version,
                  key: "#{buildpack1.guid}_#{buildpack1.sha256_checksum}",
                },
                {
                  name: buildpack2_other_name,
                  version: buildpack2_version,
                  key: "#{buildpack2.guid}_#{buildpack2.sha256_checksum}",
                },
              ]
            end

            it 'persists the multi-field buildpacks and reads them back' do
              lifecycle_data.buildpacks = lifecycle_buildpacks
              lifecycle_data.save
              new_buildpacks = lifecycle_data.reload.buildpacks
              expect(new_buildpacks.size).to eq(2)
              expect(new_buildpacks).to match_array(%w/pleasant-valley-buildpack stepping-stone-buildpack/)
              expect(lifecycle_data.reload.buildpack_lifecycle_buildpacks.
                      map { |d| { version: d[:version], name: d[:buildpack_name], buildpack_name: d.name } }).
                to match_array([
                  { version: '3.1',
                    name: 'valley',
                    buildpack_name: 'pleasant-valley-buildpack'
                  },
                  { version: '95',
                    name: 'gilooley',
                    buildpack_name: 'stepping-stone-buildpack'
                  },
                ])
            end
          end

          context 'when the lifecycle already contains a list of buildpacks' do
            subject(:lifecycle_data) do
              BuildpackLifecycleDataModel.create(buildpacks: ['some-buildpack', 'another-buildpack'])
            end

            it 'overrides the list of buildpacks and reads it back' do
              expect(lifecycle_data.buildpacks).to eq ['some-buildpack', 'another-buildpack']

              lifecycle_data.buildpacks = ['new-buildpack']
              lifecycle_data.save
              expect(lifecycle_data.reload.buildpacks).to eq ['new-buildpack']
            end

            it 'deletes the buildpacks when the lifecycle is deleted' do
              lifecycle_data_guid = lifecycle_data.guid
              expect(lifecycle_data_guid).to_not be_nil
              expect(BuildpackLifecycleBuildpackModel.where(buildpack_lifecycle_data_guid: lifecycle_data_guid)).to_not be_empty

              lifecycle_data.destroy
              expect(BuildpackLifecycleBuildpackModel.where(buildpack_lifecycle_data_guid: lifecycle_data_guid)).to be_empty
            end
          end
        end

        context 'when using both a buildpack name and buildpack url' do
          it 'persists the buildpacks and reads them back' do
            lifecycle_data.buildpacks = ['some-buildpack', 'http://foo:bar@buildpackurl.com']
            lifecycle_data.save
            expect(lifecycle_data.reload.buildpacks).to eq ['some-buildpack', 'http://foo:bar@buildpackurl.com']
            expect(lifecycle_data.reload.buildpack_lifecycle_buildpacks.map(&:buildpack_url)).to eq [nil, 'http://foo:bar@buildpackurl.com']
            expect(lifecycle_data.reload.buildpack_lifecycle_buildpacks.map(&:admin_buildpack_name)).to eq ['some-buildpack', nil]
          end
        end

        context 'when supporting rolling deploys' do
          context 'when the first buildpack specified is a custom url' do
            it 'persists the buildpack with legacy fields' do
              lifecycle_data.buildpacks = ['http://buildpack.example.com']
              lifecycle_data.save
              expect(lifecycle_data.reload.legacy_buildpack_url).to eq 'http://buildpack.example.com'
              expect(lifecycle_data.reload.legacy_admin_buildpack_name).to be_nil
            end

            it 'reads a buildpack that was saved with legacy buildpack_url field' do
              lifecycle_data.legacy_buildpack_url = 'http://buildpack.example.com'
              lifecycle_data.save
              expect(lifecycle_data.reload.buildpacks).to eq ['http://buildpack.example.com']
            end
          end

          context 'when the first buildpack specified is an admin buildpack' do
            it 'persists the buildpack with legacy fields' do
              lifecycle_data.buildpacks = ['ruby']
              lifecycle_data.save
              expect(lifecycle_data.reload.legacy_buildpack_url).to be_nil
              expect(lifecycle_data.reload.legacy_admin_buildpack_name).to eq 'ruby'
            end

            it 'reads a buildpack that was saved with legacy admin_buildpack_name field' do
              lifecycle_data.legacy_admin_buildpack_name = 'ruby'
              lifecycle_data.save
              expect(lifecycle_data.reload.buildpacks).to eq ['ruby']
            end
          end
        end
      end

      context 'admin buildpack name' do
        let(:buildpack) { Buildpack.make(name: 'ruby') }

        it 'persists the buildpack' do
          lifecycle_data.buildpacks = ['ruby']
          lifecycle_data.save
          expect(lifecycle_data.reload.buildpacks).to eq ['ruby']
        end

        context 'when supporting rolling deploys' do
          it 'also persists the buildpack under the legacy column' do
            lifecycle_data.buildpacks = ['ruby']
            lifecycle_data.save
            expect(lifecycle_data.reload.legacy_admin_buildpack_name).to eq 'ruby'
          end
        end
      end
    end

    describe '#buildpack_models' do
      context 'when no buildpack is set' do
        before { lifecycle_data.buildpacks = nil }

        it 'returns an array with a single AutoDetectionBuildpack' do
          expect(lifecycle_data.buildpack_models).to eq([AutoDetectionBuildpack.new])
        end
      end

      context 'when the buildpacks are a mixture of admin and custom buildpacks' do
        let(:admin_buildpack) { Buildpack.make(name: 'minbari') }
        let(:buildpack1_url) { 'http://example.com/buildpack1' }
        let(:buildpack2_url) { 'http://example.com/buildpack2' }

        before do
          lifecycle_data.buildpacks = [admin_buildpack.name, buildpack1_url, buildpack2_url]
        end

        it 'returns an array of corresponding buildpack objects' do
          expect(lifecycle_data.buildpack_models).to eq([admin_buildpack,
                                                         CustomBuildpack.new(buildpack1_url),
                                                         CustomBuildpack.new(buildpack2_url)])
        end
      end

      context 'when the buildpack is set via the legacy_* fields' do
        context 'when the buildpack is an admin buildpack' do
          let(:admin_buildpack) { Buildpack.make(name: 'susperia') }

          before do
            lifecycle_data.legacy_admin_buildpack_name = admin_buildpack.name
          end

          it 'returns an array of 1 Buildpack' do
            expect(lifecycle_data.buildpack_models).to eq([admin_buildpack])
          end
        end

        context 'when the buildpack is a custom buildpack' do
          let(:buildpack_url) { 'http://example.org/wedgemount' }

          before do
            lifecycle_data.legacy_buildpack_url = buildpack_url
          end

          it 'returns an array of 1 Custom Buildpack' do
            expect(lifecycle_data.buildpack_models).to eq([CustomBuildpack.new(buildpack_url)])
          end
        end
      end
    end

    describe '#legacy_buildpack_model' do
      let!(:admin_buildpack) { Buildpack.make(name: 'bob') }

      context 'when the buildpack is nil' do
        subject(:lifecycle_data) { BuildpackLifecycleDataModel.new(buildpacks: nil) }

        it 'is AutoDetectionBuildpack' do
          expect(lifecycle_data.send(:legacy_buildpack_model)).to be_an(AutoDetectionBuildpack)
        end
      end

      context 'when the buildpack is an admin buildpack' do
        subject(:lifecycle_data) { BuildpackLifecycleDataModel.new(buildpacks: [admin_buildpack.name]) }

        it 'is the matching admin buildpack' do
          expect(lifecycle_data.send(:legacy_buildpack_model)).to eq(admin_buildpack)
        end
      end

      context 'when the buildpack is a custom buildpack (url)' do
        let(:custom_buildpack_url) { 'https://github.com/buildpacks/the-best' }
        subject(:lifecycle_data) { BuildpackLifecycleDataModel.new(buildpacks: [custom_buildpack_url]) }

        it 'is a custom buildpack for the URL' do
          # Temporary: legacy-buildpacks will be removed when the rolling-deploy support for
          # singular => multiple buildpacks ends.
          legacy_buildpack_model = lifecycle_data.send(:legacy_buildpack_model)
          expect(legacy_buildpack_model).to be_a(CustomBuildpack)
          expect(legacy_buildpack_model.url).to eq(custom_buildpack_url)
        end
      end
    end

    describe '#using_custom_buildpack?' do
      context 'when using a custom buildpack' do
        context 'when using a single-instance legacy buildpack' do
          subject(:lifecycle_data) { BuildpackLifecycleDataModel.new }

          it 'returns true' do
            lifecycle_data.legacy_buildpack_url = 'https://someurl.com'
            expect(lifecycle_data.using_custom_buildpack?).to eq true
          end
        end

        context 'when using mutiple buildpacks' do
          subject(:lifecycle_data) {
            BuildpackLifecycleDataModel.new(buildpacks: ['https://github.com/buildpacks/the-best', 'ruby'])
          }

          it 'returns true' do
            expect(lifecycle_data.using_custom_buildpack?).to eq true
          end
        end
      end

      context 'when not using a custom buildpack' do
        subject(:lifecycle_data) { BuildpackLifecycleDataModel.new(buildpacks: nil) }

        it 'returns false' do
          expect(lifecycle_data.using_custom_buildpack?).to eq false
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
          subject(:lifecycle_data) {
            BuildpackLifecycleDataModel.new(buildpacks: ['ruby', 'https://github.com/buildpacks/the-best'])
          }

          it 'returns the first url' do
            expect(lifecycle_data.first_custom_buildpack_url).to eq 'https://github.com/buildpacks/the-best'
          end
        end

        context 'and there are not any custom buildpacks' do
          subject(:lifecycle_data) {
            BuildpackLifecycleDataModel.new(buildpacks: ['ruby', 'java'])
          }

          it 'returns nil' do
            expect(lifecycle_data.first_custom_buildpack_url).to be_nil
          end
        end
      end
    end

    describe '#to_hash' do
      let(:expected_lifecycle_data) do
        { buildpacks: buildpacks || [], stack: 'cflinuxfs2' }
      end
      let(:buildpacks) { [buildpack] }
      let(:buildpack) { 'ruby' }
      let(:stack) { 'cflinuxfs2' }

      before do
        Buildpack.make(name: 'ruby')
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

      it 'adds BuildpackLifecyleBuildpack errors to the BuildpackLifecycleDataModels' do
        app = AppModel.make
        lifecycle_data.app = app
        lifecycle_data.buildpacks = ['invalid_buildpack_name']
        expect(lifecycle_data.valid?).to be(false)
        expect(lifecycle_data.errors.full_messages.size).to eq(1)
        expect(lifecycle_data.errors.full_messages.first).to include('Specified unknown buildpack name: "invalid_buildpack_name"')
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
