require "spec_helper"

module VCAP::CloudController
  describe Buildpack, type: :model do

    class TestError < StandardError; end

    def get_bp_ordered
      Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
    end

    before do
      @model_manager = ModelManager.new(Buildpack)
      @model_manager.record
    end

    after do
      @model_manager.destroy
    end

    describe "validations" do
      it "enforces unique names" do
        Buildpack.make(name: "my_custom_buildpack")

        expect {
          Buildpack.make(name: "my_custom_buildpack")
        }.to raise_error(Sequel::ValidationFailed, /name unique/)
      end
    end

    describe "listing admin buildpacks" do
      let(:blobstore) { double :buildpack_blobstore }

      let(:buildpack_file_1) { Tempfile.new("admin buildpack 1") }
      let(:buildpack_file_2) { Tempfile.new("admin buildpack 2") }
      let(:buildpack_file_3) { Tempfile.new("admin buildpack 3") }

      let(:buildpack_blobstore) { CloudController::DependencyLocator.instance.buildpack_blobstore }

      before do
        Timecop.freeze # The expiration time of the blobstore uri
        Buildpack.dataset.delete
      end

      subject(:all_buildpacks) { Buildpack.list_admin_buildpacks }

      context "with prioritized buildpacks" do
        before do
          buildpack_blobstore.cp_to_blobstore(buildpack_file_1.path, "a key")
          Buildpack.make(key: "a key", position: 2)

          buildpack_blobstore.cp_to_blobstore(buildpack_file_2.path, "b key")
          Buildpack.make(key: "b key", position: 1)

          buildpack_blobstore.cp_to_blobstore(buildpack_file_3.path, "c key")
          @another_buildpack = Buildpack.make(key: "c key", position: 3)
        end

        it { should have(3).items }

        it "returns the list in position order" do
          expect(all_buildpacks.collect(&:key)).to eq(["b key", "a key", "c key"])
        end

        it "doesn't list any buildpacks with null keys" do
          @another_buildpack.key = nil
          @another_buildpack.save

          expect(all_buildpacks).to_not include(@another_buildpack)
          expect(all_buildpacks).to have(2).items
        end

        it "randomly orders any buildpacks with the same position (for now we did not want to make clever logic of shifting stuff around: up to the user to get it all correct)" do
          @another_buildpack.position = 1
          @another_buildpack.save

          expect(all_buildpacks[2].key).to eq("a key")
        end

        context "and there are buildpacks with null keys" do
          let!(:null_buildpack) { Buildpack.create(:name => "nil_key_custom_buildpack", :position => 0) }

          it "only returns buildpacks with non-null keys" do
            expect(Buildpack.all).to include(null_buildpack)
            expect(all_buildpacks).to_not include(null_buildpack)
            expect(all_buildpacks).to have(3).items
          end
        end

        context "and there are buildpacks with empty keys" do
          let!(:empty_buildpack) { Buildpack.create(:name => "nil_key_custom_buildpack", :key => "", :position => 0) }

          it "only returns buildpacks with non-null keys" do
            expect(Buildpack.all).to include(empty_buildpack)
            expect(all_buildpacks).to_not include(empty_buildpack)
            expect(all_buildpacks).to have(3).items
          end
        end
      end

      context "when there are no buildpacks" do
        it "should cope with no buildpacks" do
          expect(all_buildpacks).to be_empty
        end
      end

      context "when there are disabled buildpacks" do
        let!(:enabled_buildpack) { Buildpack.make(:key => "enabled-buildpack", :enabled => true) }
        let!(:disabled_buildpack) { Buildpack.make(:key => "disabled-buildpack", :enabled => false) }

        it "includes them in the list" do
          expect(all_buildpacks).to match_array([enabled_buildpack, disabled_buildpack])
        end
      end
    end

    describe "staging_message" do
      it "contains the buildpack key" do
        buildpack = Buildpack.make
        expect(buildpack.staging_message).to eql(buildpack_key: buildpack.key)
      end
    end

    describe ".at_last_position" do
      let!(:buildpacks) do
        4.times.map { |i| Buildpack.create(name: "name_#{100 - i}", position: i + 1) }
      end

      it "gets the last position" do
        expect(Buildpack.at_last_position).to eq buildpacks[3]
      end

      context "no buildpacks in the database" do
        let(:buildpacks) { nil }

        it "should return nil" do
          expect(Buildpack.at_last_position).to be_nil
        end
      end
    end

    describe ".create" do
      context "with a specified position" do
        it "creates a buildpack entry at the lowest position" do
          expect {
            Buildpack.create(name: "new_buildpack", key: "abcdef", position: 5)
          }.to change {
            get_bp_ordered
          }.from([]).to([["new_buildpack", 1]])
        end

        it "has a position 0 specified" do
          bp = Buildpack.create(name: "new_buildpack", key: "abcdef", position: 0)
          expect(bp.position).to(eql(1))
        end
      end

      context "without a specified position" do
        it "creates a buildpack entry at the lowest position" do
          expect {
            Buildpack.create(name: "new_buildpack", key: "abcdef")
          }.to change {
            get_bp_ordered
          }.from([]).to([["new_buildpack", 1]])
        end
      end

      it "also locks the last position so that the moves don't race condition it" do
        last = double(:last, position: 4)
        allow(Buildpack).to receive(:at_last_position) { last }
        expect(last).to receive(:lock!)
        Buildpack.create(name: "new_buildpack", key: "abcdef", position: 2)
      end

      context "when other buildpacks exist" do
        let!(:buildpacks) do
          4.times.map { |i| Buildpack.make(name: "name_#{100 - i}", position: i + 1) }
        end

        it "must be transactional so that shifting positions remains consistent" do
          expect {
            expect{
              Buildpack.create(name: "new_buildpack", key: "abcdef", position: 2) do
                  raise TestError.new "intentional error during Buildpack.create"
              end
            }.to raise_error(TestError)
          }.not_to change {
            get_bp_ordered
          }.from([["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]])
        end

        context "with a specified position" do
          it "creates a buildpack at position 1 when less than 1" do
            expect {
              Buildpack.create(name: "new_buildpack", key: "abcdef", position: 0)
            }.to change {
              get_bp_ordered
            }.from(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
                 ).to(
                   [["new_buildpack", 1], ["name_100", 2], ["name_99", 3], ["name_98", 4], ["name_97", 5]]
                 )
          end

          it "creates a buildpack entry at the lowest position" do
            expect {
              Buildpack.create(name: "new_buildpack", key: "abcdef", position: 7)
            }.to change {
              get_bp_ordered
            }.from(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
                 ).to(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4], ["new_buildpack", 5]]
                 )
          end

          it "creates a buildpack entry and moves all other buildpacks" do
            expect {
              Buildpack.create(name: "new_buildpack", key: "abcdef", position: 2)
            }.to change {
              get_bp_ordered
            }.from(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
                 ).to(
                   [["name_100", 1], ["new_buildpack", 2], ["name_99", 3], ["name_98", 4], ["name_97", 5]]
                 )
          end

          it "allows an insert at the current last position" do
            expect {
              Buildpack.create(name: "new_buildpack", key: "abcdef", position: 4)
            }.to change {
              get_bp_ordered
            }.from(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
                 ).to(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["new_buildpack", 4], ["name_97", 5]]
                 )
          end
        end

        context "without a specified position" do
          it "creates a buildpack entry at the lowest position" do
            expect {
              Buildpack.create(name: "new_buildpack", key: "abcdef")
            }.to change {
              get_bp_ordered
            }.from(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
                 ).to(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4], ["new_buildpack", 5]]
                 )
          end
        end

        context "and called with a block" do
          it "orders based on position" do
            expect {
              Buildpack.create do |bp|
                bp.set_all(name: "new_buildpack", key: "abcdef", position: 1)
              end
            }.to change {
              get_bp_ordered
            }.from(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
                 ).to(
                   [["new_buildpack", 1], ["name_100", 2], ["name_99", 3], ["name_98", 4], ["name_97", 5]]
                 )
          end
        end
      end
    end

    describe ".update" do
      let!(:buildpacks) do
        4.times.map { |i| Buildpack.create(name: "name_#{100 - i}", position: i + 1) }
      end

      it "locks the current object so that the moves don't race condition it" do
        expect(buildpacks[0]).to receive(:lock!)
        Buildpack.update(buildpacks[0], {key: "abcdef"})
      end

      it "locks the last position so that the moves don't race condition it" do
        allow(Buildpack).to receive(:at_last_position) { buildpacks.last }
        expect(buildpacks.last).to receive(:lock!)
        Buildpack.update(buildpacks.first, {position: 2})
      end

      it "must be transactional so that shifting positions remains consistent" do
        buildpack = buildpacks[3]
        allow(buildpack).to receive(:update_from_hash) do
          raise TestError.new "intentional error during Buildpack.update"
        end

        expect {
          expect{
            Buildpack.update(buildpack, position: 2)
          }.to raise_error(TestError)
        }.not_to change {
          get_bp_ordered
        }.from([["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]])
      end

      it "has to do a SELECT FOR UPDATE" do
        expect(Buildpack).to receive(:for_update).exactly(1).and_call_original
        Buildpack.update(buildpacks[3], position: 2)
      end

      it "locks the last row" do
        last = double(:last, position: 4)
        allow(Buildpack).to receive(:at_last_position) { last }
        expect(last).to receive(:lock!)
        Buildpack.update(buildpacks[3], position: 2)
      end

      it "does not update the position if it isn't specified" do
        expect {
          Buildpack.update(buildpacks.first, {key: "abcdef"})
        }.to_not change {
          get_bp_ordered
        }
      end

      it "doesn't try to change the position needlessly" do
        expect(buildpacks[0]).to_not receive(:update)
        expect {
          Buildpack.update(buildpacks[0], position: 1)
        }.to_not change {
          get_bp_ordered
        }
      end

      it "does not modify the frozen hash provided by Sequel" do
        expect {
          Buildpack.update(buildpacks.first, {position: 2}.freeze)
        }.not_to raise_error
      end

      it "shifts from the end to the beginning" do
        expect {
          Buildpack.update(buildpacks[3], position: 1)
        }.to change {
          get_bp_ordered
        }.from(
               [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
             ).to(
               [["name_97", 1], ["name_100", 2], ["name_99", 3], ["name_98", 4]]
             )
      end

      it "shifts in the middle" do
        expect {
          Buildpack.update(buildpacks[3], position: 2)
        }.to change {
          get_bp_ordered
        }.from(
               [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
             ).to(
               [["name_100", 1], ["name_97", 2], ["name_99", 3], ["name_98", 4]]
             )
      end

      it "shifts from the beginning to the end" do
        expect {
          Buildpack.update(buildpacks.first, {position: 4})
        }.to change {
          get_bp_ordered
        }.from(
               [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
             ).to(
               [["name_99", 1], ["name_98", 2], ["name_97", 3], ["name_100", 4]]
             )
      end

      context "when updating past" do
        context "the beginning" do
          it "normalizes to the beginning of the list" do
            expect {
              Buildpack.update(buildpacks[1], {position: 0})
            }.to change {
              get_bp_ordered
            }.from(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
                 ).to(
                   [["name_99", 1], ["name_100", 2], ["name_98", 3], ["name_97", 4]]
                 )
          end

          it "doesn't change the position if there isn't a change after normalization" do
            expect(buildpacks[0]).to_not receive(:update)
            expect {
              Buildpack.update(buildpacks[0], position: 0)
            }.to_not change {
              get_bp_ordered
            }
          end
        end

        context "the end" do
          it "normalizes the position to a valid one" do
            expect {
              Buildpack.update(buildpacks[2], position: 5)
            }.to change {
              get_bp_ordered
            }.from(
                   [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
                 ).to(
                   [["name_100", 1], ["name_99", 2], ["name_97", 3], ["name_98", 4]]
                 )
          end

          it "doesn't change the position if there isn't a change after normalization" do
            expect(buildpacks[3]).to_not receive(:update)
            expect {
              Buildpack.update(buildpacks[3], position: 5)
            }.to_not change {
              get_bp_ordered
            }
          end
        end
      end
    end

    describe "destroy" do
      let!(:buildpack1) { Buildpack.create({name: "first_buildpack", key: "xyz", position: 5}) }
      let!(:buildpack2) { Buildpack.create({name: "second_buildpack", key: "xyz", position: 10}) }

      it "removes the specified buildpack" do
        expect {
          buildpack1.destroy
        }.to change {
          get_bp_ordered
        }.from(
               [["first_buildpack", 1], ["second_buildpack", 2]]
             ).to(
               [["second_buildpack", 1]]
             )
      end

      it "doesn't shift when the last position is deleted" do
        expect {
          buildpack2.destroy
        }.to change {
          get_bp_ordered
        }.from(
               [["first_buildpack", 1], ["second_buildpack", 2]]
             ).to(
               [["first_buildpack", 1]]
             )
      end
    end

    describe "to_json" do
      it "does not string mung(e)?" do
        expect(Buildpack.new(name: "my_custom_buildpack\r\n").to_json).to eq '"my_custom_buildpack\r\n"'
      end
    end

    describe "custom" do
      it "is not custom" do
        expect(subject.custom?).to be_false
      end
    end
  end
end
