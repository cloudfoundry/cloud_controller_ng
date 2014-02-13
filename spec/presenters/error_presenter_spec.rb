require "spec_helper"

describe ErrorPresenter do
  let(:error) do
    StandardError.new
  end

  let(:error_hasher) do
    double(ErrorHasher, hashify: {fake: 'error'})
  end

  subject(:presenter) do
    ErrorPresenter.new(error, error_hasher)
  end

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

  describe "#client_error?" do
    context "when the response code is 4xx" do
      before do
        allow(error).to receive(:response_code).and_return(403)
      end

      it { should be_a_client_error }
    end

    context "when the response code is not 4xx" do
      before do
        allow(error).to receive(:response_code).and_return(500)
      end

      it { should_not be_a_client_error }
    end
  end

  describe "#log_message" do
    it "logs the response code and error hash" do
      expect(presenter.log_message).to eq("Request failed: 500: {:fake=>\"error\"}")
    end
  end

  describe "#payload" do
    it "returns hash representation of the error" do
      expect(presenter.payload).to eq(fake: 'error')
      expect(error_hasher).to have_received(:hashify).with(error, false)
    end
  end

  describe "#reponse_code" do
    context "when the error knows its response code" do
      before do
        allow(error).to receive(:response_code).and_return(403)
      end

      it "returns the error's response code" do
        expect(presenter.response_code).to eq(error.response_code)
      end
    end

    context "when the error does not have an associated response code" do
      it "returns 500" do
        expect(presenter.response_code).to eq(500)
      end
    end
  end
end
