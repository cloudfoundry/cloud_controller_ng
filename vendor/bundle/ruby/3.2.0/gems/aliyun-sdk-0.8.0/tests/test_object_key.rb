# coding: utf-8
require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require_relative 'config'

class TestObjectKey < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)

    @prefix = 'tests/object_key/'
    @keys = {
      simple: 'simple_key',
      chinese: '杭州・中国',
      space: '是 空格 yeah +-/\\&*#',
      invisible: '' << 1 << 10 << 12 << 7 << 80 << 99,
      specail1: 'testkey/',
      specail2: 'testkey/?key=value#abc=def',
      xml: 'a<b&c>d +'
    }
  end

  def get_key(sym)
    @prefix + @keys[sym]
  end

  def test_simple
    key = get_key(:simple)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_chinese
    key = get_key(:chinese)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_space
    key = get_key(:space)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_invisible
    key = get_key(:invisible)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_specail1
    key = get_key(:specail1)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_specail2
    key = get_key(:specail2)
    @bucket.put_object(key)
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert_includes all, key
    assert_equal key, @bucket.get_object(key).key
  end

  def test_batch_delete
    keys = @keys.map { |k, _| get_key(k) }
    keys.each { |k| @bucket.put_object(k) }
    ret = @bucket.batch_delete_objects(keys)
    assert_equal keys, ret
    all = @bucket.list_objects(prefix: @prefix).map(&:key)
    assert all.empty?, all.to_s
  end
end
