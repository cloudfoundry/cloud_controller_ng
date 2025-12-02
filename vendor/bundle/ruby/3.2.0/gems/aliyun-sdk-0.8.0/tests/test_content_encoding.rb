require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require 'zlib'
require_relative 'config'

class TestContentEncoding < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)

    @prefix = "tests/content_encoding/"
  end

  def get_key(k)
    "#{@prefix}#{k}"
  end

  def test_gzip_encoding
    key = get_key('gzip')
    File.open('/tmp/x', 'w') do |f|
      1000.times { f.write 'hello world' * 1024 }
    end

    @bucket.put_object(
      key, file: '/tmp/x', content_type: 'text/plain')

    @bucket.get_object(
      key, file: '/tmp/y', headers: {'accept-encoding' => 'gzip'})

    assert File.exist?('/tmp/y')
    diff = `diff /tmp/x /tmp/y`
    assert diff.empty?
  end

  def test_deflate_encoding
    key = get_key('deflate')
    File.open('/tmp/x', 'w') do |f|
      1000.times { f.write 'hello world' * 1024 }
    end

    @bucket.put_object(
      key, file: '/tmp/x', content_type: 'text/plain')

    @bucket.get_object(
      key, file: '/tmp/y', headers: {'accept-encoding' => 'deflate'})

    assert File.exist?('/tmp/y')
    diff = `diff /tmp/x /tmp/y`
    assert diff.empty?
  end
end
