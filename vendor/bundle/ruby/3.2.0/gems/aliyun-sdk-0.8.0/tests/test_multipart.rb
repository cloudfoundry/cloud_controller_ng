# coding: utf-8
require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require_relative 'config'

class TestMultipart < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket_name = TestConf.bucket
    @bucket = client.get_bucket(TestConf.bucket)

    @protocol = Aliyun::OSS::Protocol.new(Aliyun::OSS::Config.new(TestConf.creds))
    @prefix = 'tests/multipart/'
  end

  def get_key(k)
    @prefix + k
  end

  def clear_uploads
    all = @bucket.list_uploads.to_a
    all.each { |t| @bucket.abort_upload(t.id, t.object) }
  end

  def test_key_marker
    clear_uploads

    # initiate 5 uploads
    ids = []
    5.times { |i|
      id = @protocol.initiate_multipart_upload(@bucket_name, get_key("obj-#{i}"))
      ids << id
    }

    all = @bucket.list_uploads(limit: 1).to_a
    assert_equal ids, all.map(&:id)

    after_1 = @bucket.list_uploads(key_marker: get_key("obj-0")).to_a
    assert_equal ids[1, 5], after_1.map(&:id)

    after_5 = @bucket.list_uploads(key_marker: get_key("obj-4")).to_a
    assert after_5.empty?, after_5.to_s
  end

  def test_id_marker
    clear_uploads

    # initiate 5 uploads
    ids = []
    5.times { |i|
      id = @protocol.initiate_multipart_upload(@bucket_name, get_key("object"))
      ids << id
    }
    ids.sort!

    all = @bucket.list_uploads.to_a
    assert_equal ids, all.map(&:id)

    # id_marker is ignored
    after_1 = @bucket.list_uploads(id_marker: ids[0]).to_a
    assert_equal ids, after_1.map(&:id)

    # id_marker is ignored
    after_5 = @bucket.list_uploads(id_marker: ids[4]).to_a
    assert_equal ids, after_5.map(&:id)
  end

  def test_id_key_marker
    clear_uploads

    # initiate 5 uploads
    foo_ids = []
    5.times { |i|
      id = @protocol.initiate_multipart_upload(@bucket_name, get_key("foo"))
      foo_ids << id
    }
    foo_ids.sort!

    bar_ids = []
    5.times { |i|
      id = @protocol.initiate_multipart_upload(@bucket_name, get_key("bar"))
      bar_ids << id
    }
    bar_ids.sort!

    after_1 = @bucket.list_uploads(
      id_marker: bar_ids[0], key_marker: get_key("bar"), limit: 1).to_a
    assert_equal bar_ids[1, 5] + foo_ids, after_1.map(&:id)

    after_5 = @bucket.list_uploads(
      id_marker: bar_ids[4], key_marker: get_key("bar")).to_a
    assert_equal foo_ids, after_5.map(&:id)
  end
end
