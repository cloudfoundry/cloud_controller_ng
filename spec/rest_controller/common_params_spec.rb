require "spec_helper"

module VCAP::CloudController::RestController
  describe CommonParams do
    let(:logger) do
      double("Logger").as_null_object
    end

    subject(:common_params) do
      CommonParams.new(logger)
    end

    describe "#parse" do
      it "treats inline-relations-depth as an Integer and symbolizes the key" do
        expect(common_params.parse({"inline-relations-depth" => "123"})).to eq({:inline_relations_depth => 123})
      end

      it "treats page as an Integer and symbolizes the key" do
        expect(common_params.parse({"page" => "123"})).to eq({:page => 123})
      end
      it "treats results-per-page as an Integer and symbolizes the key" do
        expect(common_params.parse({"results-per-page" => "123"})).to eq({:results_per_page => 123})
      end

      it "treats q as a String and symbolizes the key" do
        expect(common_params.parse({"q" => "123"})).to eq({:q => "123"})
      end

      it "treats order direction as a String and symbolizes the key" do
        expect(common_params.parse({"order-direction" => "123"})).to eq({:order_direction => "123"})
      end

      it "discards other params" do
        expect(common_params.parse({"foo" => "bar"})).to eq({})
      end
    end
  end
end
