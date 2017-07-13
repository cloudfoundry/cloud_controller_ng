require 'spec_helper'

module VCAP::CloudController
  RSpec.describe CustomBuildpack do
    subject(:buildpack) { CustomBuildpack.new(url) }

    let(:url) { 'http://foo_bar/baz' }

    its(:url) { should == url }
    its(:to_json) { should == '"http://foo_bar/baz"' }

    it 'has the correct staging message' do
      expect(buildpack.staging_message).to include(buildpack_git_url: url)
    end

    it 'has the deprecated staging message' do
      expect(buildpack.staging_message).to include(buildpack: url)
    end

    it 'is custom' do
      expect(buildpack.custom?).to be true
    end
  end
end
