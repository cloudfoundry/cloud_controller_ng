require "spec_helper"

describe ErrorHasher do
  subject(:error_hasher) { ErrorHasher.new(error) }

  let(:sanitized_hash) do
    error_hasher.sanitized_hash
  end

  let(:unsanitized_hash) do
    error_hasher.unsanitized_hash
  end

  describe "UNKNOWN_ERROR_HASH" do
    it "should be a minimal error hash" do
      expect(ErrorHasher::UNKNOWN_ERROR_HASH).to have_key("code")
      expect(ErrorHasher::UNKNOWN_ERROR_HASH).to have_key("description")
      expect(ErrorHasher::UNKNOWN_ERROR_HASH).to have_key("error_code")
    end
  end

  describe "given an ApiError" do
    let(:error) { VCAP::Errors::ApiError.new_from_details("DomainInvalid", "notadomain") }
    it { should be_an_api_error }
    it { should_not be_a_services_error }

    it "uses the error's error_code as 'code'" do
      expect(unsanitized_hash["code"]).to eq(130001)
    end

    describe "sanitized hash" do
      it "does not change the error code" do
        expect(sanitized_hash["error_code"]).to eq(error_hasher.unsanitized_hash["error_code"])
      end

      it "does not change the description" do
        expect(sanitized_hash["description"]).to eq(error_hasher.unsanitized_hash["description"])
      end
    end
  end

  describe "given a services error" do
    let(:error) { StructuredError.new("my message", "my source") }
    it { should be_a_services_error }
    it { should_not be_an_api_error }

    it "uses the default code" do
      expect(unsanitized_hash["code"]).to eq(10001)
    end

    describe "sanitized hash" do
      it "does not change the error code" do
        expect(sanitized_hash["error_code"]).to eq(error_hasher.unsanitized_hash["error_code"])
      end

      it "does not change the description" do
        expect(sanitized_hash["description"]).to eq(error_hasher.unsanitized_hash["description"])
      end

      it "does not change the error code" do
        expect(sanitized_hash["error_code"]).to eq(error_hasher.unsanitized_hash["error_code"])
      end

      it "does not change the description" do
        expect(sanitized_hash["description"]).to eq(error_hasher.unsanitized_hash["description"])
      end
    end
  end

  describe "given a non-api exception" do
    class FakeError < StandardError
      def backtrace
        "fake backtrace"
      end
    end

    let(:error) { FakeError.new("fake error message") }

    it { should_not be_a_services_error }
    it { should_not be_an_api_error }

    describe "#unsanitized_hash" do
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

    context "when the error knows how to convert itself into a hash" do
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
        allow(error).to receive(:to_h).and_return("source" => "fake_source")
      end

      it "returns the error hash with the 'source' key" do
        expect(unsanitized_hash).to have_key("source")
      end
    end

    describe "#sanitized_hash" do
      before do
        allow(error).to receive(:to_h).and_return("backtrace" => "fake_backtrace", "source" => "fake_source")
      end

      subject(:sanitized_hash) do
        error_hasher.sanitized_hash
      end

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
