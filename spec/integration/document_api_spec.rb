require "spec_helper"

describe "bin/document_api" do
  let(:document_api) { File.expand_path("../../../bin/document_api", __FILE__) }

  it "is executable without failure" do
    %x[ #{document_api} ]
    $?.exitstatus.should == 0
  end
end