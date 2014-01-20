require "spec_helper"

module VCAP::CloudController
  describe Buildpack, type: :model do
    def get_bp_ordered
      Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
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

      context "when there unprioritized buildpacks (position=0)" do
        let!(:unprioritized_buildpacks) do
          Buildpack.make(:key => "Java", :position => 0)
          Buildpack.make(:key => "Ruby", :position => 0)
        end

        it "returns the list in position order with unprioritized at the end" do
          buildpack_blobstore.cp_to_blobstore(buildpack_file_1.path, "a key")
          Buildpack.make(key: "a key", position: 1)

          build_packs = all_buildpacks.map(&:key)
          expect(build_packs[0..-3]).to eq ["a key"]
          expect(build_packs[-2..-1]).to match_array ["Java", "Ruby"]
        end

        it "copes if there all zeros" do
          build_packs = all_buildpacks.map(&:key)
          expect(build_packs).to match_array ["Java", "Ruby"]
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

    describe "positioning buildpacks" do
      let!(:buildpacks) do
        4.times.map { |i| Buildpack.create(name: "name_#{100 - i}", position: i + 1) }
      end

      describe ".at_last_position" do
        it "gets the last position" do
          expect(Buildpack.at_last_position).to eq buildpacks[3]
        end

        context "no buildpacks in the database" do
          let(:buildpacks) { nil }

          it "should return nul" do
            expect(Buildpack.at_last_position).to be_nil
          end
        end
      end

      describe "#shift_to_position" do
        it "must be transactional so that shifting positions remains consistent" do
          expect(Buildpack.db).to receive(:transaction).exactly(2).times.and_yield
          buildpacks[3].shift_to_position(2)
        end

        it "has to do a SELECT FOR UPDATE" do
          expect(Buildpack).to receive(:for_update).exactly(1).and_call_original
          buildpacks[3].shift_to_position(2)
        end

        it "locks the last row" do
          last = double(:last, position: 4)
          allow(Buildpack).to receive(:at_last_position) { last }
          expect(last).to receive(:lock!)
          buildpacks[3].shift_to_position(2)
        end

        context "when an empty table" do
          let(:buildpacks) { nil }

          it "should only allow setting position to 1" do
            bp = Buildpack.new(name: "name_1")
            bp.shift_to_position(5)
            bp.save
            expect(bp.reload.position).to eq 1
          end
        end

        context "shifting up" do
          it "shifting up when already the first to the first" do
            expect {
              buildpacks[0].shift_to_position(1)
            }.to_not change {
              get_bp_ordered
            }
          end

          it "shifting up when already the last to the first" do
            expect {
              buildpacks[3].shift_to_position(1)
            }.to change {
              get_bp_ordered
            }.from(
              [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
            ).to(
              [["name_97", 1], ["name_100", 2], ["name_99", 3], ["name_98", 4]]
            )
          end

          it "shifting up and not the first" do
            expect {
              buildpacks[3].shift_to_position(2)
            }.to change {
              get_bp_ordered
            }.from(
              [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
            ).to(
              [["name_100", 1], ["name_97", 2], ["name_99", 3], ["name_98", 4]]
            )
          end

          context "and shifting to 0" do
            it "shifting from the middle" do
              expect {
                buildpacks[2].shift_to_position(0)
              }.to change {
                get_bp_ordered
              }.from(
                [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
              ).to(
                [["name_98", 0], ["name_100", 1], ["name_99", 2], ["name_97", 3]]
              )
            end

            it "shifting from the end" do
              expect {
                buildpacks[3].shift_to_position(0)
              }.to change {
                get_bp_ordered
              }.from(
                [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
              ).to(
                [["name_97", 0], ["name_100", 1], ["name_99", 2], ["name_98", 3]]
              )
            end

            it "shifting two buildpacks" do
              expect {
                buildpacks[3].shift_to_position(0)
                buildpacks[0].shift_to_position(0)
              }.to change {
                get_bp_ordered
              }.from(
                [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
              )

              result = get_bp_ordered
              expect(result[2..-1]).to eq([["name_99", 1], ["name_98", 2]])
              expect(result[0..1]).to match_array([["name_100", 0], ["name_97", 0]])
            end
          end

          it "doesn't try resetting the position" do
            expect(buildpacks[0]).to_not receive(:update)
            buildpacks[0].shift_to_position(1)
          end
        end

        context "shifting down" do
          it "shifting down when already the last and beyond last" do
            expect {
              buildpacks[3].shift_to_position(5)
            }.to_not change {
              get_bp_ordered
            }
          end

          it "shifting down to last" do
            expect {
              buildpacks[2].shift_to_position(4)
            }.to change {
              get_bp_ordered
            }.from(
              [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
            ).to(
              [["name_100", 1], ["name_99", 2], ["name_97", 3], ["name_98", 4]]
            )
          end

          it "shifting down beyond last" do
            expect {
              buildpacks[2].shift_to_position(5)
            }.to change {
              get_bp_ordered
            }.from(
              [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4]]
            ).to(
              [["name_100", 1], ["name_99", 2], ["name_97", 3], ["name_98", 4]]
            )
          end

          it "doesn't try resetting the position" do
            expect(buildpacks[3]).to_not receive(:update)
            buildpacks[3].shift_to_position(5)
          end
        end
      end
    end

    describe ".create" do
      context "with a specified position" do
        it "creates a buildpack entry at the lowest position" do
          expect {
            Buildpack.create(name: "new_buildpack", key: "abcdef")
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
            Buildpack.create(name: "new_buildpack", key: "abcdef", position: 7)
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
          expect(Buildpack.db).to receive(:transaction).exactly(2).times.and_yield
          Buildpack.create(name: "new_buildpack", key: "abcdef", position: 2)
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
      let!(:buildpack1) { VCAP::CloudController::Buildpack.create({name: "first_buildpack", key: "xyz", position: 5}) }
      let!(:buildpack2) { VCAP::CloudController::Buildpack.create({name: "second_buildpack", key: "xyz", position: 10}) }

      it "locks the current object so that the moves don't race condition it" do
        expect(buildpack1).to receive(:lock!)
        Buildpack.update(buildpack1, {key: "abcdef"})
      end

      it "locks the last position so that the moves don't race condition it" do
        allow(Buildpack).to receive(:at_last_position) { buildpack2 }
        expect(buildpack2).to receive(:lock!)
        Buildpack.update(buildpack1, {'position' => 2})
      end

      context "when other buildpacks exist" do
        let!(:buildpacks) do
          4.times.map { |i| Buildpack.create(name: "name_#{100 - i}", position: i + 1) }
        end

        it "must be transactional so that shifting positions remains consistent" do
          expect(Buildpack.db).to receive(:transaction).exactly(4).times.and_yield
          Buildpack.update(buildpack2, {'position' => 1})
        end

        context "with a specified position" do
          it "updates the buildpack to position 1 when less than 1" do
            expect {
              Buildpack.update(buildpack2, {'position' => 0})
            }.to change {
              get_bp_ordered
            }.from(
              [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4], ["first_buildpack", 5], ["second_buildpack", 6]]
            ).to(
              [["second_buildpack", 1], ["name_100", 2], ["name_99", 3], ["name_98", 4], ["name_97", 5], ["first_buildpack", 6]]
            )
          end

          it "updates a buildpack entry at the lowest position" do
            expect {
              Buildpack.update(buildpack1, {'position' => 7})
            }.to change {
              get_bp_ordered
            }.from(
              [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4], ["first_buildpack", 5], ["second_buildpack", 6]]
            ).to(
              [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4], ["second_buildpack", 5], ["first_buildpack", 6]]
            )
          end

          it "updates the buildpack entry and moves all other buildpacks" do
            expect {
              Buildpack.update(buildpack2, {'position' => 2})
            }.to change {
              get_bp_ordered
            }.from(
              [["name_100", 1], ["name_99", 2], ["name_98", 3], ["name_97", 4], ["first_buildpack", 5], ["second_buildpack", 6]]
            ).to(
              [["name_100", 1], ["second_buildpack", 2], ["name_99", 3], ["name_98", 4], ["name_97", 5], ["first_buildpack", 6]]
            )
          end
        end

        context "without a specified position" do
          it "does not update the position" do
            expect {
              Buildpack.update(buildpack1, {key: "abcdef"})
            }.to_not change {
              get_bp_ordered
            }
          end
        end
      end
    end

    describe "to_json" do
      it "does not string mung(e)?" do
        expect(Buildpack.new(name: "my_custom_buildpack\r\n").to_json).to eq '"my_custom_buildpack\r\n"'
      end
    end
  end
end
