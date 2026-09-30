require 'spec_helper'

RSpec.describe UriUtils do
  describe '.is_custom_stack_uri?' do
    it 'returns true for valid docker:// URIs' do
      expect(UriUtils.is_custom_stack_uri?('docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0')).to be(true)
      expect(UriUtils.is_custom_stack_uri?('docker://registry.example.com/my-org/my-stack:latest')).to be(true)
      expect(UriUtils.is_custom_stack_uri?('docker://ghcr.io/cloudfoundry/cflinuxfs4:1.0.0')).to be(true)
    end

    it 'returns true for docker:// URIs without explicit tags (defaults to latest)' do
      expect(UriUtils.is_custom_stack_uri?('docker://docker.io/cloudfoundry/cflinuxfs4')).to be(true)
    end

    it 'returns true for docker:// URIs with digest' do
      expect(UriUtils.is_custom_stack_uri?('docker://docker.io/cloudfoundry/cflinuxfs4@sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890')).to be(true)
    end

    it 'returns false for non-string inputs' do
      expect(UriUtils.is_custom_stack_uri?(nil)).to be(false)
      expect(UriUtils.is_custom_stack_uri?(123)).to be(false)
      expect(UriUtils.is_custom_stack_uri?({})).to be(false)
    end

    it 'returns false for plain stack names' do
      expect(UriUtils.is_custom_stack_uri?('cflinuxfs4')).to be(false)
      expect(UriUtils.is_custom_stack_uri?('cflinuxfs3')).to be(false)
    end

    it 'returns false for http/https URIs' do
      expect(UriUtils.is_custom_stack_uri?('https://example.com/stack')).to be(false)
      expect(UriUtils.is_custom_stack_uri?('http://example.com/stack')).to be(false)
    end

    it 'returns false for invalid docker URIs' do
      expect(UriUtils.is_custom_stack_uri?('docker://')).to be(false)
      expect(UriUtils.is_custom_stack_uri?('docker://INVALID_UPPERCASE')).to be(false)
    end
  end
end
