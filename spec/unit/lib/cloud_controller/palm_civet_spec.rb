require 'spec_helper'
require 'cloud_controller/palm_civet'

module VCAP::CloudController
  RSpec.describe PalmCivet do
    describe "#byte_size" do
      it "prints in the largest possible unit" do
        expect(PalmCivet.byte_size(10 * PalmCivet::TERABYTE)).to eq("10T")
        expect(PalmCivet.byte_size(10.5 * PalmCivet::TERABYTE)).to eq("10.5T")

        expect(PalmCivet.byte_size(10 * PalmCivet::GIGABYTE)).to eq("10G")
        expect(PalmCivet.byte_size(10.5 * PalmCivet::GIGABYTE)).to eq("10.5G")

        expect(PalmCivet.byte_size(100 * PalmCivet::MEGABYTE)).to eq("100M")
        expect(PalmCivet.byte_size(100.5 * PalmCivet::MEGABYTE)).to eq("100.5M")

        expect(PalmCivet.byte_size(100 * PalmCivet::KILOBYTE)).to eq("100K")
        expect(PalmCivet.byte_size(100.5 * PalmCivet::KILOBYTE)).to eq("100.5K")

        expect(PalmCivet.byte_size(1)).to eq("1B")
      end

      it "prints '0' for zero bytes" do
        expect(PalmCivet.byte_size(0)).to eq("0")
      end

      it "raises a type error on non-number values" do
        expect {
          PalmCivet.byte_size("something else")
        }.to raise_error(TypeError, "must be an integer or float")
      end
    end

    describe "#to_bytes" do
      it "parses byte amounts with short units (e.g. M, G)" do
        expect(PalmCivet.to_bytes("5B")).to eq(5)
        expect(PalmCivet.to_bytes("5K")).to eq(5 * PalmCivet::KILOBYTE)
        expect(PalmCivet.to_bytes("5M")).to eq(5 * PalmCivet::MEGABYTE)
        expect(PalmCivet.to_bytes("5G")).to eq(5 * PalmCivet::GIGABYTE)
        expect(PalmCivet.to_bytes("5T")).to eq(5 * PalmCivet::TERABYTE)
      end

      it "parses byte amounts that are float (e.g. 5.3KB)" do
        expect(PalmCivet.to_bytes("13.5KB")).to eq(13824)
        expect(PalmCivet.to_bytes("4.5KB")).to eq(4608)
        expect(PalmCivet.to_bytes("2.55KB")).to eq(2611)
      end

      it "parses byte amounts with long units (e.g MB, GB)" do
        expect(PalmCivet.to_bytes("5MB")).to eq(5 * PalmCivet::MEGABYTE)
        expect(PalmCivet.to_bytes("5mb")).to eq(5 * PalmCivet::MEGABYTE)
        expect(PalmCivet.to_bytes("2GB")).to eq(2 * PalmCivet::GIGABYTE)
        expect(PalmCivet.to_bytes("3TB")).to eq(3 * PalmCivet::TERABYTE)
      end

      it "parses byte amounts with long binary units (e.g MiB, GiB)" do
        expect(PalmCivet.to_bytes("5MiB")).to eq(5 * PalmCivet::MEGABYTE)
        expect(PalmCivet.to_bytes("5mib")).to eq(5 * PalmCivet::MEGABYTE)
        expect(PalmCivet.to_bytes("2GiB")).to eq(2 * PalmCivet::GIGABYTE)
        expect(PalmCivet.to_bytes("3TiB")).to eq(3 * PalmCivet::TERABYTE)
      end

      it "allows whitespace before and after the value" do
        expect(PalmCivet.to_bytes("\t\n\r 5MB ")).to eq(5 * PalmCivet::MEGABYTE)
      end

      context 'when the byte amount is 0' do
        it 'returns 0 bytes' do
          expect(PalmCivet.to_bytes("0TB")).to eq(0)
        end
      end

      context 'when the byte amount is negative' do
        it 'returns a negative amount of bytes' do
          expect(PalmCivet.to_bytes('-200B')).to eq(-200)
        end
      end

      context "raises an error" do
        it "when the unit is missing" do
          expect {
            PalmCivet.to_bytes("5")
          }.to raise_error(PalmCivet::InvalidByteQuantityError)
        end

        it "when the unit is unrecognized" do
          expect {
            PalmCivet.to_bytes("5MBB")
          }.to raise_error(PalmCivet::InvalidByteQuantityError)

          expect {
            PalmCivet.to_bytes("5BB")
          }.to raise_error(PalmCivet::InvalidByteQuantityError)
        end
      end
    end

    describe "#to_megabytes" do
      it "parses byte amounts with short units (e.g. M, G)" do
        expect(PalmCivet.to_megabytes("5B")).to eq(0)
        expect(PalmCivet.to_megabytes("5K")).to eq(0)
        expect(PalmCivet.to_megabytes("5M")).to eq(5)
        expect(PalmCivet.to_megabytes("5m")).to eq(5)
        expect(PalmCivet.to_megabytes("5G")).to eq(5120)
        expect(PalmCivet.to_megabytes("5T")).to eq(5242880)
      end

      it "parses byte amounts with long units (e.g MB, GB)" do
        expect(PalmCivet.to_megabytes("5B")).to eq(0)
        expect(PalmCivet.to_megabytes("5KB")).to eq(0)
        expect(PalmCivet.to_megabytes("5MB")).to eq(5)
        expect(PalmCivet.to_megabytes("5mb")).to eq(5)
        expect(PalmCivet.to_megabytes("5GB")).to eq(5120)
        expect(PalmCivet.to_megabytes("5TB")).to eq(5242880)
      end

      it "parses byte amounts with long binary units (e.g MiB, GiB)" do
        expect(PalmCivet.to_megabytes("5B")).to eq(0)
        expect(PalmCivet.to_megabytes("5KiB")).to eq(0)
        expect(PalmCivet.to_megabytes("5MiB")).to eq(5)
        expect(PalmCivet.to_megabytes("5mib")).to eq(5)
        expect(PalmCivet.to_megabytes("5GiB")).to eq(5120)
        expect(PalmCivet.to_megabytes("5TiB")).to eq(5242880)
      end

      it "allows whitespace before and after the value" do
        expect(PalmCivet.to_megabytes("\t\n\r 5MB ")).to eq(5)
      end

      context 'when the byte amount is 0' do
        it 'returns 0 megabytes' do
          expect(PalmCivet.to_megabytes('0TB')).to eq(0)
        end
      end

      context 'when the byte amount is negative' do
        it 'returns a negative amount of megabytes' do
          expect(PalmCivet.to_megabytes('-200MB')).to eq(-200)
        end
      end

      context "raises an error" do
        it "when the unit is missing" do
          expect {
            PalmCivet.to_megabytes("5")
          }.to raise_error(PalmCivet::InvalidByteQuantityError)
        end

        it "when the unit is unrecognized" do
          expect {
            PalmCivet.to_megabytes("5MBB")
          }.to raise_error(PalmCivet::InvalidByteQuantityError)

          expect {
            PalmCivet.to_megabytes("5BB")
          }.to raise_error(PalmCivet::InvalidByteQuantityError)
        end
      end
    end
  end
end
