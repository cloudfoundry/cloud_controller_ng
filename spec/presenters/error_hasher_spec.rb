require "spec_helper"

describe ErrorHasher do
  subject(:error_hasher) { ErrorHasher.new(error) }

  let(:unknown_error) do
    error = RuntimeError.new("fake message")
    error.set_backtrace("fake backtrace")
    error
  end

  let(:services_error) do
    error = StructuredError.new("fake message", "fake source")
    error.set_backtrace("fake backtrace")
    error
  end

  let(:api_error) do
    error = VCAP::Errors::ApiError.new_from_details("DomainInvalid", "notadomain")
    error.set_backtrace("fake backtrace")
    error
  end

  let(:to_h_error) do
    error = RuntimeError.new("fake message")
    error.set_backtrace("fake backtrace")
    allow(error).to receive(:to_h).and_return("arbritratry key" => "arbritratry value", "code" => 67890, "source" => "fake source")
    error
  end

  describe "UNKNOWN_ERROR_HASH" do
    it "should be a minimal error hash" do
      expect(ErrorHasher::UNKNOWN_ERROR_HASH).to have_key("code")
      expect(ErrorHasher::UNKNOWN_ERROR_HASH).to have_key("description")
      expect(ErrorHasher::UNKNOWN_ERROR_HASH).to have_key("error_code")
    end
  end

  describe "#services_error?" do
    subject { error_hasher.services_error? }
    context "for a StructuredError" do
      let(:error) { services_error }
      it { should be_true }
    end

    context "for an ApiError" do
      let(:error) { api_error }
      it { should be_false }
    end

    context "for an UnknownError" do
      let(:error) { unknown_error }
      it { should be_false }
    end
  end

  describe "#api_error?" do
    subject { error_hasher.api_error? }
    context "for a StructuredError" do
      let(:error) { services_error }
      it { should be_false }
    end

    context "for an ApiError" do
      let(:error) { api_error }
      it { should be_true }
    end

    context "for an UnknownError" do
      let(:error) { unknown_error }
      it { should be_false }
    end
  end

  describe "#unsanitized_hash" do
    subject(:unsanitized_hash) do
      error_hasher.unsanitized_hash
    end

    context "when the error knows how to convert itself into a hash" do
      let(:error) { to_h_error }

      it "lets the error do the conversion" do
        expect(unsanitized_hash).to eq({"code"=>67890,
                                        "description"=>"fake message",
                                        "error_code"=>"CF-RuntimeError",
                                        "backtrace"=>["fake backtrace"],
                                        "arbritratry key"=>"arbritratry value",
                                        "source"=>"fake source"})
      end
    end

    context "with an ApiError" do
      let(:error) { api_error }

      it "uses a standard convention by default" do
        expect(unsanitized_hash).to eq({"code"=>130001,
                                        "description"=>"The domain is invalid: notadomain",
                                        "error_code"=>"CF-DomainInvalid",
                                        "backtrace"=>["fake backtrace"]})
      end
    end

    context "with a services error" do
      let(:error) { services_error }

      it "uses a standard convention by default" do
        expect(unsanitized_hash).to eq({"code"=>10001,
                                        "description"=>"fake message",
                                        "error_code"=>"CF-StructuredError",
                                        "backtrace"=>["fake backtrace"],
                                        "source"=>"fake source"})
      end
    end

    context "with nil" do
      let(:error) { nil }

      it "returns a default hash" do
        expect(unsanitized_hash).to eq({
                                         "error_code" => "UnknownError",
                                         "description" => "An unknown error occurred.",
                                         "code" => 10001,
                                       })
      end
    end

    context "with an unknown error" do
      let(:error) { unknown_error }

      it "uses a standard convention by default" do
        expect(unsanitized_hash).to eq({"code"=>10001,
                                        "description"=>"fake message",
                                        "error_code"=>"CF-RuntimeError",
                                        "backtrace"=>["fake backtrace"]})
      end
    end
  end

  describe "#sanitized_hash" do
    subject(:sanitized_hash) do
      error_hasher.sanitized_hash
    end

    context "when the error knows how to convert itself into a hash" do
      let(:error) { to_h_error }

      it "lets the error do the conversion" do
        expect(sanitized_hash).to eq({"code"=>67890,
                                      "description"=>"An unknown error occurred.",
                                      "error_code"=>"UnknownError",
                                      "arbritratry key"=>"arbritratry value"})
      end
    end

    context "with an ApiError" do
      let(:error) { api_error }

      it "uses a standard convention by default" do
        expect(sanitized_hash).to eq({"code"=>130001,
                                      "description"=>"The domain is invalid: notadomain",
                                      "error_code"=>"CF-DomainInvalid"
                                     })
      end
    end

    context "with a services error" do
      let(:error) { services_error }

      it "uses a standard convention by default" do
        expect(sanitized_hash).to eq({"code"=>10001,
                                      "description"=>"fake message",
                                      "error_code"=>"CF-StructuredError"})
      end
    end

    context "with nil" do
      let(:error) { nil }

      it "returns a default hash" do
        expect(sanitized_hash).to eq({
                                       "error_code" => "UnknownError",
                                       "description" => "An unknown error occurred.",
                                       "code" => 10001,
                                     })
      end
    end

    context "with an unknown error" do
      let(:error) { unknown_error }

      it "uses a standard convention by default" do
        expect(sanitized_hash).to eq({"code"=>10001,
                                      "description"=>"An unknown error occurred.",
                                      "error_code"=>"UnknownError"})
      end
    end
  end
end
