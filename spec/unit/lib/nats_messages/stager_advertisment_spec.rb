require "spec_helper"
require "cloud_controller/nats_messages/stager_advertisment"

describe StagerAdvertisement do
  let(:message) do
    {
      "id" => "staging-id",
      "stacks" => ["stack-name"],
      "available_memory" => 1024,
      "available_disk" => 2048,
      "app_id_to_count" => {
        "app_id" => 2,
        "app_id_2" => 1
      }
    }
  end

  subject(:ad) { StagerAdvertisement.new(message) }

  describe "#stager_id" do
    its(:stager_id) { should eq "staging-id" }
  end

  describe "#stats" do
    its(:stats) { should eq message }
  end

  describe "#available_memory" do
    its(:available_memory) { should eq 1024 }
  end

  describe "#available_disk" do
    its(:available_disk) { should eq 2048 }
  end

  describe "#expired?" do
    let(:now) { Time.now }
    context "when the time since the advertisment is greater than 10 seconds" do
      it "returns false" do
        Timecop.freeze now do
          ad
          Timecop.freeze now + 11.seconds do
            expect(ad).to be_expired
          end
        end
      end
    end

    context "when the time since the advertisment is less than or equal to 10 seconds" do
      it "returns false" do
        Timecop.freeze now do
          ad
          Timecop.freeze now + 10.seconds do
            expect(ad).to_not be_expired
          end
        end
      end
    end
  end

  describe "#meets_needs?" do
    context "when it has the memory" do
      let(:mem) { 512 }

      context "and it has the stack" do
        let(:stack) { "stack-name" }
        it { expect(ad.meets_needs?(mem, stack)).to be true }
      end

      context "and it does not have the stack" do
        let(:stack) { "not-a-stack-name" }
        it { expect(ad.meets_needs?(mem, stack)).to be false }
      end
    end

    context "when it does not have the memory" do
      let(:mem) { 2048 }

      context "and it has the stack" do
        let(:stack) { "stack-name" }
        it { expect(ad.meets_needs?(mem, stack)).to be false }
      end

      context "and it does not have the stack" do
        let(:stack) { "not-a-stack-name" }
        it { expect(ad.meets_needs?(mem, stack)).to be false }
      end
    end
  end

  describe "#has_sufficient_memory?" do
    context "when the stager does not have enough memory" do
      it "returns false" do
        expect(ad.has_sufficient_memory?(2048)).to be false
      end
    end

    context "when the stager has enough memory" do
      it "returns false" do
        expect(ad.has_sufficient_memory?(512)).to be true
      end
    end
  end

  describe "#has_sufficient_disk?" do
    context "when the dea does not have enough disk" do
      it "returns false" do
        expect(ad.has_sufficient_disk?(2049)).to be false
      end
    end

    context "when the dea does have enough disk" do
      it "returns false" do
        expect(ad.has_sufficient_disk?(512)).to be true
      end
    end

    context "when the dea does not report disk space" do
      before { message.delete "available_disk" }

      it "always returns true" do
        expect(ad.has_sufficient_disk?(4096 * 10)).to be true
      end
    end
  end

  describe "#zone" do
    context "when the dea does not have the placement properties" do
      it "returns default zone" do
        expect(ad.zone).to eq "default"
      end
    end

    context "when the dea has empty placement properties" do
      before { message["placement_properties"] = {} }

      it "returns default zone" do
        expect(ad.zone).to eq "default"
      end
    end

    context "when the dea has the placement properties with zone info" do
      before { message["placement_properties"] = {"zone" => "zone_cf"} }

      it "returns the zone with name zone_cf" do
        expect(ad.zone).to eq "zone_cf"
      end
    end
  end

  describe "#num_instances_of" do
    it { expect(ad.num_instances_of("app_id")).to eq 2 }
    it { expect(ad.num_instances_of("not_on_dea")).to eq 0 }
  end

  describe "#num_instances_of_all" do
    context "when app_id_to_count > 0" do
      it { expect(ad.num_instances_of_all).to eq 3 }
    end

    context "when app_id_to_count = 0" do
      before do
        message["app_id_to_count"] = {}
      end

      it { expect(ad.num_instances_of_all).to eq 0 }
    end
  end

  describe "#has_stack?" do
    context "when the stager has the stack" do
      it "returns false" do
        expect(ad.has_stack?("stack-name")).to be true
      end
    end

    context "when the stager does not have the stack" do
      it "returns false" do
        expect(ad.has_stack?("not-a-stack-name")).to be false
      end
    end
  end

  describe "decrement_memory" do
    it "decrement the stager's memory" do
      expect {
        ad.decrement_memory(512)
      }.to change {
        ad.available_memory
      }.from(1024).to(512)
    end
  end

  describe "#decrement_disk" do
    it "decrement the stager's disk" do
      expect {
        ad.decrement_disk(1024)
      }.to change {
        ad.available_disk
      }.from(2048).to(1024)
    end
  end
end
