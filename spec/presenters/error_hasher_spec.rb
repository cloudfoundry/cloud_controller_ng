require "spec_helper"

describe ErrorHasher do
  describe "#hashify" do
    class FakeError < StandardError
      def backtrace
        "fake backtrace"
      end
    end

    let(:error) do
      FakeError.new("fake error message")
    end

    let(:api_error) do
      false
    end

    subject(:hashified_error) do
      hasher = ErrorHasher.new
      hasher.hashify(error, api_error)
    end

    context "by default" do
      it "uses a code of 10001" do
        expect(hashified_error["code"]).to eq(10001)
      end

      it "uses the error's message as the description" do
        expect(hashified_error["description"]).to eq("fake error message")
      end

      it "uses the error's class name as its error_code" do
        expect(hashified_error["error_code"]).to eq("CF-FakeError")
      end
    end

    context "when the error is an api error" do
      let(:api_error) do
        true
      end

      before do
        allow(error).to receive(:error_code).and_return(12345)
      end

      it "uses the error's error_code as 'code'" do
        expect(hashified_error["code"]).to eq(12345)
      end
    end

    context "when the error knows how to converty itself into a hash" do
      before do
        allow(error).to receive(:to_h).and_return("fake" => "error", "code" => 67890)
      end

      it "lets the error do the conversion" do
        expect(hashified_error["fake"]).to eq("error")
        expect(hashified_error["code"]).to eq(67890)
      end
    end

    context "when the error does not know how to convert itself into a hash" do
      it "uses a standard convention" do
        expect(hashified_error).to eq({
                                        "code" => 10001,
                                        "description" => "fake error message",
                                        "error_code" => "CF-FakeError",
                                        "types"=>["FakeError"],
                                        "backtrace" => "fake backtrace"
                                      })
      end
    end
  end
end
