require "spec_helper"

module VCAP::CloudController
  describe GitBasedBuildpack do
    let(:url) { "http://foo_bar/baz" }
    subject { GitBasedBuildpack.new(url) }

    its(:url) { should == url }
    its(:to_json) { should == "\"#{url}\"" }

    it "has the correct staging message" do
      expect(subject.staging_message).to include(buildpack_git_url: url)
    end

    it "has the deprecated staging message" do
      expect(subject.staging_message).to include(buildpack: url)
    end
  end
end
