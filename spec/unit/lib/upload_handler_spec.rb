require "spec_helper"

describe UploadHandler do
  let(:key) { "application" }
  subject(:uploader) { UploadHandler.new(config) }

  context "Nginx mode" do
    let(:config) { { nginx: { use_nginx: true } } }

    context "when the file exists" do
      let(:params) { { "#{key}_path" => "a path" } }

      it "expects the {name}_path variable to contain the uploaded file path" do
        expect(uploader.uploaded_file(params, key)).to eq("a path")
      end
    end

    context "when the file doesn't exist" do
      let(:params) { { "foobar_path" => "a path" } }

      it "expects the {name}_path variable to contain the uploaded file path" do
        expect(uploader.uploaded_file(params, key)).to be_nil
      end
    end
  end

  context "Rack Mode" do
    let(:config) { { nginx: { use_nginx: false } } }

    context "and the tempfile key is a symbol" do
      let(:params) { { key => { tempfile: Struct.new(:path).new("a path") } } }

      it "returns the uploaded file from the :tempfile synthetic variable" do
        expect(uploader.uploaded_file(params, "application")).to eq("a path")
      end
    end

    context "and the value of the tmpfile is path" do
      let(:params) { { key => { "tempfile" => "a path" } } }

      it "returns the uploaded file from the tempfile synthetic variable" do
        expect(uploader.uploaded_file(params, "application")).to eq("a path")
      end
    end

    context "and there is no file" do
      let(:params) { { key => nil } }

      it "returns nil" do
        expect(uploader.uploaded_file(params, "application")).to be_nil
      end
    end
  end
end