require 'spec_helper'

module VCAP::Errors
  describe ApiError do
    let(:details) do
      double(Details,
             name: "ServiceInvalid",
             response_code: 400,
             code: 12345,
             message_format: "Before %s %s after.")
    end

    let(:name) { "ServiceInvalid" }

    before do
      allow(Details).to receive("new").with(name).and_return(details)
    end

    context ".new_from_details" do
      let(:args) { [ "foo", "bar" ] }

      subject(:api_error) { ApiError.new_from_details(name, *args) }

      it "returns an ApiError" do
        expect(api_error).to be_a(ApiError)
      end

      it "should be an exception" do
        expect(api_error).to be_a(Exception)
      end

      it "sets the message using the format provided in the v2.yml" do
        expect(api_error.message).to eq("Before foo bar after.")
      end

      context "if it doesn't recognise the error from v2.yml" do
        let(:name) { "What is this?  I don't know?!!"}

        before do
          allow(Details).to receive(:new).and_call_original
        end

        it "explodes" do
          expect { api_error }.to raise_error
        end
      end
    end

    context "with details" do
      subject(:api_error) { ApiError.new }

      before do
        api_error.details = details
      end

      it "exposes the code" do
        expect(api_error.code).to eq(12345)
      end

      it "exposes the http code" do
        expect(api_error.response_code).to eq(400)
      end

      it "exposes the name" do
        expect(api_error.name).to eq("ServiceInvalid")
      end
    end
  end
end