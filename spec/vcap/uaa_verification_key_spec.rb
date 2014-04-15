require "spec_helper"
require "vcap/uaa_verification_key"

module VCAP
  describe UaaVerificationKey do
    subject { described_class.new(config_hash[:verification_key], uaa_info) }

    let(:config_hash) do
      {:url => "http://uaa-url"}
    end

    let(:uaa_info) { double(CF::UAA::Info) }

    describe "#value" do
      context "when config does not specify verification key" do
        before { config_hash[:verification_key] = nil }
        before { uaa_info.stub(:validation_key => {"value" => "value-from-uaa"}) }

        context "when key was never fetched" do
          it "is fetched" do
            expect(uaa_info).to receive(:validation_key)
            expect(subject.value).to eq "value-from-uaa"
          end
        end

        context "when key was fetched before" do
          before do
            uaa_info.should_receive(:validation_key) # sanity
            subject.value
          end

          it "is not fetched again" do
            uaa_info.should_not_receive(:validation_key)
            subject.value.should == "value-from-uaa"
          end
        end
      end

      context "when config specified verification key" do
        before { config_hash[:verification_key] = "value-from-config" }

        it "returns key specified in config" do
          subject.value.should == "value-from-config"
        end

        it "is not fetched" do
          uaa_info.should_not_receive(:validation_key)
          subject.value
        end
      end
    end

    describe "#refresh" do
      context "when config does not specify verification key" do
        before { config_hash[:verification_key] = nil }
        before { uaa_info.stub(:validation_key => {"value" => "value-from-uaa"}) }

        context "when key was never fetched" do
          it "is fetched" do
            expect(uaa_info).to receive(:validation_key)
            subject.refresh
            subject.value.should == "value-from-uaa"
          end
        end

        context "when key was fetched before" do
          before do
            uaa_info.should_receive(:validation_key) # sanity
            subject.value
          end

          it "is RE-fetched again" do
            expect(uaa_info).to receive(:validation_key)
            subject.refresh
            subject.value.should == "value-from-uaa"
          end
        end
      end

      context "when config specified verification key" do
        before { config_hash[:verification_key] = "value-from-config" }

        it "returns key specified in config" do
          subject.refresh
          subject.value.should == "value-from-config"
        end

        it "is not fetched" do
          uaa_info.should_not_receive(:validation_key)
          subject.refresh
          subject.value.should == "value-from-config"
        end
      end
    end
  end
end
