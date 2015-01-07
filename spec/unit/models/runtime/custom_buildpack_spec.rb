require 'spec_helper'

module VCAP::CloudController
  describe CustomBuildpack do
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

    it 'is valid' do
      expect(buildpack).to be_valid
    end

    describe 'validations' do
      context 'with an ssh based git url' do
        let(:url) { 'git@example.com:foo/bar.git' }

        its(:to_json) { should == '"git@example.com:foo/bar.git"' }

        it 'should not be valid' do
          expect(buildpack).not_to be_valid
          expect(buildpack.errors).to include "#{url} is not valid public url or a known buildpack name"
        end
      end

      context 'with bogus characters at the start of the URI' do
        let(:url) { "\r\nhttp://foo_bar/baz" }

        its(:to_json) { should == '"\r\nhttp://foo_bar/baz"' }

        it 'should not be valid' do
          expect(buildpack).not_to be_valid
          expect(buildpack.errors).to include "#{url} is not valid public url or a known buildpack name"
        end
      end

      context 'with bogus characters at the end of the URI' do
        let(:url) { "http://foo_bar/baz\r\n\0" }

        its(:to_json) { should == '"http://foo_bar/baz\r\n\u0000"' }

        it 'should not be valid' do
          expect(buildpack).not_to be_valid
          expect(buildpack.errors).to include "#{url} is not valid public url or a known buildpack name"
        end
      end
    end
  end
end
