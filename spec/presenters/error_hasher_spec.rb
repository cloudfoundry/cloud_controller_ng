require "spec_helper"

describe ErrorHasher do
  subject(:error_hasher) { ErrorHasher.new(error) }

  describe "given a real exception" do
    class FakeError < StandardError
      def backtrace
        "fake backtrace"
      end
    end

    let(:error) { FakeError.new("fake error message") }

    describe "#api_error?" do
      context "when the error is one of ours" do
        before do
          allow(error).to receive(:error_code)
        end

        it { should be_an_api_error }
      end

      context "when the error is built-in or from a gem" do
        it { should_not be_an_api_error }
      end
    end

    describe "#api_error?" do
      context "when the error is one of ours" do
        before do
          allow(error).to receive(:source)
        end

        it { should be_a_services_error }
      end

      context "when the error is built-in or from a gem" do
        it { should_not be_a_services_error }
      end
    end

    describe "#unsanitized_hash" do
      subject(:unsanitized_hash) do
        error_hasher.unsanitized_hash
      end

      context "by default" do
        it "uses a code of 10001" do
          expect(unsanitized_hash["code"]).to eq(10001)
        end

        it "uses the error's message as the description" do
          expect(unsanitized_hash["description"]).to eq("fake error message")
        end

        it "uses the error's class name as its error_code" do
          expect(unsanitized_hash["error_code"]).to eq("CF-FakeError")
        end
      end

      context "when the error is an api error" do
        before do
          allow(error).to receive(:error_code).and_return(12345)
        end

        it "uses the error's error_code as 'code'" do
          expect(unsanitized_hash["code"]).to eq(12345)
        end
      end

      context "when the error knows how to converty itself into a hash" do
        before do
          allow(error).to receive(:to_h).and_return("fake" => "error", "code" => 67890)
        end

        it "lets the error do the conversion" do
          expect(unsanitized_hash["fake"]).to eq("error")
          expect(unsanitized_hash["code"]).to eq(67890)
        end
      end

      context "when the error does not know how to convert itself into a hash" do
        it "uses a standard convention" do
          expect(unsanitized_hash).to eq({
                                           "code" => 10001,
                                           "description" => "fake error message",
                                           "error_code" => "CF-FakeError",
                                           "types" => ["FakeError"],
                                           "backtrace" => "fake backtrace"
                                         })
        end
      end

      context "when there is a source and backtrace key" do
        before do
          allow(error).to receive(:to_h).and_return("backtrace" => "fake_backtrace", "source" => "fake_source")
        end

        it "returns the error hash with the 'source' key" do
          expect(unsanitized_hash).to have_key("source")
        end

        it "returns the error hash with the 'backtrace' key" do
          expect(unsanitized_hash).to have_key("backtrace")
        end
      end

    end

    describe "#sanitized_hash" do
      before do
        allow(error).to receive(:to_h).and_return("backtrace" => "fake_backtrace", "source" => "fake_source")
      end

      subject(:sanitized_hash) do
        error_hasher.sanitized_hash
      end

      context "when the error is not an api error" do
        it "sets the error code to 'UnknownError'" do
          expect(sanitized_hash["error_code"]).to eq("UnknownError")
        end

        it "sets the description to 'An unknown error occurred.'" do
          expect(sanitized_hash["description"]).to eq("An unknown error occurred.")
        end

        context "when the error doesn't know how to hash itself" do
          before do
            error.unstub(:to_h)
          end

          it "doesn't reveal the error types" do
            expect(sanitized_hash).not_to have_key("types")
          end
        end
      end

      context "when the error is a services error" do
        before do
          allow(error).to receive(:source).and_return("my source")
        end

        it "does not change the error code" do
          expect(sanitized_hash["error_code"]).to eq(error_hasher.unsanitized_hash["error_code"])
        end

        it "does not change the description" do
          expect(sanitized_hash["description"]).to eq(error_hasher.unsanitized_hash["description"])
        end
      end

      context "when the error is an api error" do
        before do
          allow(error).to receive(:error_code).and_return(12345)
        end

        it "does not change the error code" do
          expect(sanitized_hash["error_code"]).to eq(error_hasher.unsanitized_hash["error_code"])
        end

        it "does not change the description" do
          expect(sanitized_hash["description"]).to eq(error_hasher.unsanitized_hash["description"])
        end
      end

      it "returns the error hash without the 'source' key" do
        expect(sanitized_hash).not_to have_key("source")
      end

      it "returns the error hash without the 'backtrace' key" do
        expect(sanitized_hash).not_to have_key("backtrace")
      end
    end
  end

  describe "given nil" do
    let(:error) { nil }

    describe "#unsanitized_hash" do
      it "returns a default hash" do
        expect(error_hasher.unsanitized_hash).to eq({
            "error_code" => "UnknownError",
            "description" => "An unknown error occurred.",
            "code" => 10001,
          })
      end
    end
  end
end
