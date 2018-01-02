require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Buildpack, type: :model do
    def ordered_buildpacks
      Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
    end

    it { is_expected.to have_timestamp_columns }

    describe 'Validations' do
      it { is_expected.to validate_uniqueness [:name, :stack] }

      describe 'stack' do
        it 'can be changed if not set' do
          buildpack = Buildpack.create(name: 'test', stack: nil)
          buildpack.stack = Stack.make.name

          expect(buildpack).to be_valid
        end

        it 'cannot be changed once it is set' do
          buildpack = Buildpack.create(name: 'test', stack: Stack.make.name)
          buildpack.stack = Stack.make.name

          expect(buildpack).not_to be_valid
          expect(buildpack.errors.on(:stack)).to include(:buildpack_cant_change_stacks)
        end

        it 'cannot be changed to a stack that doesn\'t exist' do
          buildpack = Buildpack.create(name: 'test', stack: nil)
          buildpack.stack = 'this-stack-isnt-real'

          expect(buildpack).not_to be_valid
          expect(buildpack.errors.on(:stack)).to include(:buildpack_stack_does_not_exist)
        end
      end

      describe 'name' do
        it 'does not allow non-word non-dash characters' do
          ['git://github.com', '$abc', 'foobar!'].each do |name|
            buildpack = Buildpack.new(name: name)
            expect(buildpack).not_to be_valid
            expect(buildpack.errors.on(:name)).to be_present
          end
        end

        it 'allows word and dash characters' do
          ['name', 'name-with-dash', '-name-'].each do |name|
            buildpack = Buildpack.new(name: name)
            expect(buildpack).to be_valid
          end
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :stack, :position, :enabled, :locked, :filename }
      it { is_expected.to import_attributes :name, :stack, :position, :enabled, :locked, :filename, :key }

      it 'does not string mung(e)?' do
        expect(Buildpack.new(name: "my_custom_buildpack\r\n").to_json).to eq '"my_custom_buildpack\r\n"'
      end
    end

    describe 'listing admin buildpacks' do
      let(:blobstore) { double :buildpack_blobstore }

      let(:buildpack_file_1) { Tempfile.new('admin buildpack 1') }
      let(:buildpack_file_2) { Tempfile.new('admin buildpack 2') }
      let(:buildpack_file_3) { Tempfile.new('admin buildpack 3') }

      let(:buildpack_blobstore) { CloudController::DependencyLocator.instance.buildpack_blobstore }

      before do
        Timecop.freeze # The expiration time of the blobstore uri
        Buildpack.dataset.destroy
      end

      after do
        Timecop.return
      end

      subject(:all_buildpacks) { Buildpack.list_admin_buildpacks }

      context 'with prioritized buildpacks' do
        before do
          buildpack_blobstore.cp_to_blobstore(buildpack_file_1.path, 'a key')
          Buildpack.make(key: 'a key', position: 2)

          buildpack_blobstore.cp_to_blobstore(buildpack_file_2.path, 'b key')
          Buildpack.make(key: 'b key', position: 1)

          buildpack_blobstore.cp_to_blobstore(buildpack_file_3.path, 'c key')
          @another_buildpack = Buildpack.make(key: 'c key', position: 3)
        end

        it { is_expected.to have(3).items }

        it 'returns the list in position order' do
          expect(all_buildpacks.collect(&:key)).to eq(['b key', 'a key', 'c key'])
        end

        it "doesn't list any buildpacks with null keys" do
          @another_buildpack.key = nil
          @another_buildpack.save

          expect(all_buildpacks).to_not include(@another_buildpack)
          expect(all_buildpacks).to have(2).items
        end

        it 'randomly orders any buildpacks with the same position (for now we did not want to make clever logic of shifting stuff around: up to the user to get it all correct)' do
          @another_buildpack.position = 1
          @another_buildpack.save

          expect(all_buildpacks[2].key).to eq('a key')
        end

        context 'and there are buildpacks with null keys' do
          let!(:null_buildpack) { Buildpack.create(name: 'nil_key_custom_buildpack', stack: Stack.make.name, position: 0) }

          it 'only returns buildpacks with non-null keys' do
            expect(Buildpack.all).to include(null_buildpack)
            expect(all_buildpacks).to_not include(null_buildpack)
            expect(all_buildpacks).to have(3).items
          end
        end

        context 'and there are buildpacks with empty keys' do
          let!(:empty_buildpack) { Buildpack.create(name: 'nil_key_custom_buildpack', stack: Stack.make.name, key: '', position: 0) }

          it 'only returns buildpacks with non-null keys' do
            expect(Buildpack.all).to include(empty_buildpack)
            expect(all_buildpacks).to_not include(empty_buildpack)
            expect(all_buildpacks).to have(3).items
          end
        end
      end

      context 'when there are no buildpacks' do
        it 'should cope with no buildpacks' do
          expect(all_buildpacks).to be_empty
        end
      end

      context 'when there are disabled buildpacks' do
        let!(:enabled_buildpack) { Buildpack.make(key: 'enabled-buildpack', enabled: true) }
        let!(:disabled_buildpack) { Buildpack.make(key: 'disabled-buildpack', enabled: false) }

        it 'includes them in the list' do
          expect(all_buildpacks).to match_array([enabled_buildpack, disabled_buildpack])
        end
      end
    end

    describe 'staging_message' do
      it 'contains the buildpack key' do
        buildpack = Buildpack.make
        expect(buildpack.staging_message).to eql(buildpack_key: buildpack.key)
      end
    end

    describe '#update' do
      let!(:buildpacks) do
        Array.new(4) { |i| Buildpack.create(name: "name_#{100 - i}", stack: Stack.make.name, position: i + 1) }
      end

      it 'does not modify the frozen hash provided by Sequel' do
        expect {
          buildpacks.first.update({ position: 2 }.freeze)
        }.not_to raise_error
      end
    end

    describe '#destroy' do
      let!(:buildpack1) { VCAP::CloudController::Buildpack.create({ name: 'first_buildpack', stack: Stack.make.name, key: 'xyz', position: 1 }) }
      let!(:buildpack2) { VCAP::CloudController::Buildpack.create({ name: 'second_buildpack', stack: Stack.make.name, key: 'xyz', position: 2 }) }

      it 'removes the specified buildpack' do
        expect {
          buildpack1.destroy
        }.to change {
          ordered_buildpacks
        }.from(
          [['first_buildpack', 1], ['second_buildpack', 2]]
        ).to(
          [['second_buildpack', 1]]
        )
      end

      it "doesn't shift when the last position is deleted" do
        expect {
          buildpack2.destroy
        }.to change {
          ordered_buildpacks
        }.from(
          [['first_buildpack', 1], ['second_buildpack', 2]]
        ).to(
          [['first_buildpack', 1]]
        )
      end
    end

    describe 'custom' do
      it 'is not custom' do
        expect(subject.custom?).to be false
      end
    end
  end
end
