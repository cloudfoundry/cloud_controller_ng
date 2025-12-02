# coding: utf-8
require 'minitest/autorun'
require 'benchmark'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require_relative 'config'

class TestLargeFile < Minitest::Test
  def setup
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)

    @prefix = 'tests/large_file/'
  end

  def get_key(k)
    @prefix + k
  end

  def test_large_file_1gb
    skip "don't run it by default"

    key = get_key("large_file_1gb")
    Benchmark.bm(32) do |bm|
      bm.report("Upload with put_object: ") do
        @bucket.put_object(key, :file => './large_file_1gb')
      end

      bm.report("Upload with resumable_upload: ") do
        @bucket.resumable_upload(key, './large_file_1gb')
      end

      bm.report("Download with get_object: ") do
        @bucket.get_object(key, :file => './large_file_1gb')
      end

      bm.report("Download with resumable_download: ") do
        @bucket.resumable_download(key, './large_file_1gb')
      end
    end
  end

  def test_large_file_8gb
    skip "don't run it by default"

    key = get_key("large_file_8gb")
    Benchmark.bm(32) do |bm|
      bm.report("Upload with put_object: ") do
        @bucket.put_object(key, :file => './large_file_8gb')
      end

      bm.report("Upload with resumable_upload: ") do
        @bucket.resumable_upload(key, './large_file_8gb')
      end

      bm.report("Download with get_object: ") do
        @bucket.get_object(key, :file => './large_file_8gb')
      end

      bm.report("Download with resumable_download: ") do
        @bucket.resumable_download(key, './large_file_8gb')
      end
    end
  end
end
