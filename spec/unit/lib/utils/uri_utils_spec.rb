require 'spec_helper'
require 'utils/uri_utils'

RSpec.describe UriUtils do
  describe '.is_uri?' do
    it 'is false if the object is not a string' do
      expect(UriUtils.is_uri?(1)).to be false
      expect(UriUtils.is_uri?({})).to be false
      expect(UriUtils.is_uri?([])).to be false
      expect(UriUtils.is_uri?(nil)).to be false
      expect(UriUtils.is_uri?(-> {})).to be false
      expect(UriUtils.is_uri?(:'www.example.com/path/to/thing')).to be false
      expect(UriUtils.is_uri?(1.to_c)).to be false
    end

    context 'when the object is a string' do
      it 'is false if it is not a uri' do
        expect(UriUtils.is_uri?('this is a sentence not a uri')).to be false
      end

      it 'is false if it passes the regex but is still not a uri' do
        expect(UriUtils.is_uri?('git://user@example.com:repo')).to be false
      end

      it 'is true if it is a uri' do
        expect(UriUtils.is_uri?('http://www.example.com/foobar?baz=bar')).to be true
      end
    end
  end

  describe '.is_buildpack_uri?' do
    it 'is false if the object is not a string' do
      expect(UriUtils.is_buildpack_uri?(1)).to be false
      expect(UriUtils.is_buildpack_uri?({})).to be false
      expect(UriUtils.is_buildpack_uri?([])).to be false
      expect(UriUtils.is_buildpack_uri?(nil)).to be false
      expect(UriUtils.is_buildpack_uri?(-> {})).to be false
      expect(UriUtils.is_buildpack_uri?(:'www.example.com/path/to/thing')).to be false
      expect(UriUtils.is_buildpack_uri?(1.to_c)).to be false
    end

    it 'is true if it is a git url' do
      expect(UriUtils.is_buildpack_uri?('git://user@example.com:repo.git')).to be true
    end

    it 'is true if it is an ssh git url' do
      expect(UriUtils.is_buildpack_uri?('ssh://git@example.com:repo.git')).to be true
    end

    it 'is true if it is a uri' do
      expect(UriUtils.is_buildpack_uri?('http://www.example.com/foobar?baz=bar')).to be true
    end
  end

  describe '.is_cnb_buildpack_uri?' do
    it 'is false if the object is not a string' do
      expect(UriUtils.is_cnb_buildpack_uri?(1)).to be false
      expect(UriUtils.is_cnb_buildpack_uri?({})).to be false
      expect(UriUtils.is_cnb_buildpack_uri?([])).to be false
      expect(UriUtils.is_cnb_buildpack_uri?(nil)).to be false
      expect(UriUtils.is_cnb_buildpack_uri?(-> {})).to be false
      expect(UriUtils.is_cnb_buildpack_uri?(:'www.example.com/path/to/thing')).to be false
      expect(UriUtils.is_cnb_buildpack_uri?(1.to_c)).to be false
    end

    it 'is false if it is an git url' do
      expect(UriUtils.is_cnb_buildpack_uri?('git://user@example.com:repo.git')).to be false
    end

    it 'is false if it is an ssh git url' do
      expect(UriUtils.is_cnb_buildpack_uri?('ssh://git@example.com:repo.git')).to be false
    end

    it 'is true if it is a http uri' do
      expect(UriUtils.is_cnb_buildpack_uri?('http://www.example.com/foobar?baz=bar')).to be true
    end

    it 'is true if it is a https uri' do
      expect(UriUtils.is_cnb_buildpack_uri?('https://www.example.com/foobar?baz=bar')).to be true
    end

    it 'is true if it is a uri with docker scheme' do
      expect(UriUtils.is_cnb_buildpack_uri?('docker://nginx')).to be true
    end

    it 'is true if it is a uri with docker scheme with tag' do
      expect(UriUtils.is_cnb_buildpack_uri?('docker://nginx:latest')).to be true
    end

    it 'is true if it is a uri with docker scheme with registry, port and tag' do
      expect(UriUtils.is_cnb_buildpack_uri?('docker://registry.corp:1111/nginx:latest')).to be true
    end

    it 'returns false if it is an invalid https uri' do
      expect(UriUtils.is_cnb_buildpack_uri?('https://nginx:latest')).to be false
    end

    it 'returns false if it is an invalid docker uri' do
      expect(UriUtils.is_cnb_buildpack_uri?('docker://nginx?latest')).to be false
    end

    it 'is false if it is a uri without any scheme' do
      expect(UriUtils.is_cnb_buildpack_uri?('nginx')).to be false
    end
  end

  describe '.is_custom_stack_uri?' do
    it 'accepts valid Docker image references and identifies their registry' do
      expect(UriUtils.is_custom_stack_uri?('docker://registry.example.com/my-org/my-stack:latest')).to be(true)
      expect(UriUtils.is_custom_stack_uri?('docker://ubuntu:22.04')).to be(true)
      expect(UriUtils.custom_stack_registry_host('docker://ubuntu:22.04')).to eq('docker.io')
    end

    it 'rejects non-Docker and invalid Docker references' do
      expect(UriUtils.is_custom_stack_uri?('cflinuxfs4')).to be(false)
      expect(UriUtils.is_custom_stack_uri?('https://example.com/stack')).to be(false)
      expect(UriUtils.is_custom_stack_uri?('docker://')).to be(false)
    end
  end

  describe '.custom_stack_buildpack_identifier' do
    it 'returns the final repository component without its tag' do
      expect(UriUtils.custom_stack_buildpack_identifier('docker://registry.example.com/team/cflinuxfs4:1.268.0')).to eq('cflinuxfs4')
    end

    it 'returns the final repository component without its digest' do
      digest = 'e118d023acaee5cf13471ead39f68416ad6172ff0899f3257ce1481cd2b28a6a'

      expect(UriUtils.custom_stack_buildpack_identifier("docker://registry.example.com/team/alpine-stack@sha256:#{digest}")).to eq('alpine-stack')
    end

    it 'supports Docker Hub shorthand references' do
      expect(UriUtils.custom_stack_buildpack_identifier('docker://ubuntu:22.04')).to eq('ubuntu')
    end

    it 'returns nil for invalid or non-Docker references' do
      expect(UriUtils.custom_stack_buildpack_identifier('docker://registry.example.com/')).to be_nil
      expect(UriUtils.custom_stack_buildpack_identifier('cflinuxfs4')).to be_nil
    end
  end

  describe '.is_uri_path?' do
    it 'is false if the object is not a string' do
      expect(UriUtils.is_uri_path?(1)).to be false
      expect(UriUtils.is_uri_path?({})).to be false
      expect(UriUtils.is_uri_path?([])).to be false
      expect(UriUtils.is_uri_path?(nil)).to be false
      expect(UriUtils.is_uri_path?(-> {})).to be false
      expect(UriUtils.is_uri_path?(:'/path/to/thing')).to be false
      expect(UriUtils.is_uri_path?(1.to_c)).to be false
    end

    context 'when the object is a string' do
      it 'is false if it is a relative path' do
        expect(UriUtils.is_uri_path?('path/to/thing')).to be false
      end

      it 'is false if it starts with "//"' do
        expect(UriUtils.is_uri_path?('//path/to/thing')).to be false
      end

      it 'is true with the root path' do
        expect(UriUtils.is_uri_path?('/')).to be true
      end

      it 'is false for empty strings' do
        expect(UriUtils.is_uri_path?('')).to be false
      end

      it 'is true for valid absolute paths' do
        expect(UriUtils.is_uri_path?('/path')).to be true
        expect(UriUtils.is_uri_path?('/path/to/thing')).to be true
      end
    end
  end

  describe '.uri_escape' do
    it 'return itself if no qeury' do
      expect(UriUtils.uri_escape('abc')).to eq 'abc'
    end

    it 'return escaped query' do
      expect(UriUtils.uri_escape('https://test.com/test?name=test')).to eq 'https://test.com/test?name=test'
      expect(UriUtils.uri_escape('https://test.com/test?name=/')).to eq 'https://test.com/test?name=%2F'
      expect(UriUtils.uri_escape('https://test.com/test?name=/?')).to eq 'https://test.com/test?name=%2F%3F'
    end
  end

  describe '.parse_docker_uri' do
    it 'returns valid docker uri' do
      expect(UriUtils.parse_docker_uri('buildpack')).to eq ['', 'library/buildpack', nil]
      expect(UriUtils.parse_docker_uri('docker.io/buildpack')).to eq ['docker.io', 'library/buildpack', nil]
      expect(UriUtils.parse_docker_uri('publish/buildpack')).to eq ['', 'publish/buildpack', nil]
      expect(UriUtils.parse_docker_uri('publish/buildpack:tag')).to eq ['', 'publish/buildpack', 'tag']

      actual_result = UriUtils.parse_docker_uri('publish/buildpack@sha256:e118d023acaee5cf13471ead39f68416ad6172ff0899f3257ce1481cd2b28a6a')
      expected_result = ['', 'publish/buildpack@sha256', 'e118d023acaee5cf13471ead39f68416ad6172ff0899f3257ce1481cd2b28a6a']
      expect(actual_result).to eq expected_result

      actual_result = UriUtils.parse_docker_uri('publish/buildpack:tag@sha256:e118d023acaee5cf13471ead39f68416ad6172ff0899f3257ce1481cd2b28a6a')
      expected_result = ['', 'publish/buildpack', 'tag@sha256:e118d023acaee5cf13471ead39f68416ad6172ff0899f3257ce1481cd2b28a6a']
      expect(actual_result).to eq expected_result
    end

    it 'returns invalid docker uri' do
      expect { UriUtils.parse_docker_uri('?') }.to raise_error(UriUtils::InvalidDockerURI)
      expect { UriUtils.parse_docker_uri('publish/buildpack:') }.to raise_error(UriUtils::InvalidDockerURI)
      expect { UriUtils.parse_docker_uri('publish/buildpack:?@sha256:e118d023acaee5cf13471ead39f68416ad6172ff0899f3257ce1481cd2b28a6a') }.to raise_error(UriUtils::InvalidDockerURI)
      expect { UriUtils.parse_docker_uri('publish/buildpack@sha256:e118d0') }.to raise_error(UriUtils::InvalidDockerURI)
    end
  end

  describe '.url_has_userinfo?' do
    it 'returns true for an https URL with user:pass@' do
      expect(UriUtils.url_has_userinfo?('https://user:pass@git.example.com/acme/buildpack.git')).to be true
    end

    it 'returns true for an http URL with user only' do
      expect(UriUtils.url_has_userinfo?('http://user@example.com/buildpack.git')).to be true
    end

    it 'returns false for a clean https URL' do
      expect(UriUtils.url_has_userinfo?('https://git.example.com/acme/buildpack.git')).to be false
    end

    it 'returns false for an admin buildpack name' do
      expect(UriUtils.url_has_userinfo?('ruby_buildpack')).to be false
    end

    it 'returns false for nil' do
      expect(UriUtils.url_has_userinfo?(nil)).to be false
    end

    it 'returns false for a git+ssh URL (no userinfo field)' do
      expect(UriUtils.url_has_userinfo?('git@git.example.com:acme/buildpack.git')).to be false
    end

    it 'returns true for an https URL with an empty username but a password (token-style auth)' do
      expect(UriUtils.url_has_userinfo?('https://:token@registry.example.com/buildpack')).to be true
    end

    it 'returns true for an https URL with an IPv6 host and credentials' do
      expect(UriUtils.url_has_userinfo?('https://user:pass@[::1]:8080/buildpack')).to be true
    end

    it 'returns false for an https URL with an IPv6 host and no credentials' do
      expect(UriUtils.url_has_userinfo?('https://[::1]:8080/buildpack')).to be false
    end

    it 'returns false for a malformed URL that cannot be parsed' do
      expect(UriUtils.url_has_userinfo?('https://exa mple.com/buildpack')).to be false
    end
  end
end
