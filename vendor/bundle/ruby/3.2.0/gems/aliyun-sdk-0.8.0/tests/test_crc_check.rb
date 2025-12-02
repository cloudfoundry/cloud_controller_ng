require 'minitest/autorun'
require 'yaml'
require 'tempfile'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require_relative 'config'
require_relative 'helper'

class TestCrcCheck < Minitest::Test

  include Aliyun::Test::Helper
  
  @@tests_run = 0
  @@test_file = nil

  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)
    @prefix = 'tests/crc_check/'

    if @@tests_run == 0
      @@test_file = Tempfile.new('oss_ruby_sdk_test_crc')
      (10 * 1024).times { @@test_file.write(random_bytes(1024)) }
    end
    @@tests_run += 1
  end

  def teardown
    if @@tests_run == TestCrcCheck.runnable_methods.length
      @@test_file.unlink unless @@test_file.nil?
    end
  end

  def get_key(k)
    @prefix + k
  end

  def test_put_object
    skip unless TestConf.creds[:upload_crc_enable]

    # Check crc status
    assert(@bucket.upload_crc_enable)

    # Create a test file with 10MB random bytes to put.
    key = get_key('put_file')
    
    @bucket.put_object(key, :file => @@test_file.path)
    test_object = @bucket.get_object(key)
    assert_equal(test_object.size, 10 * 1024 * 1024)

    # Check crc wrong case.
    assert_raises Aliyun::OSS::CrcInconsistentError do
      @bucket.put_object(key, {:init_crc => 1, :file => @@test_file.path}) do |content|
        content << 'hello world.'
      end
    end

    # Put a string to oss.
    key = get_key('put_string')
    @bucket.put_object(key, :init_crc => 0) do |content|
      content << 'hello world.'
    end
    test_object = @bucket.get_object(key)
    assert_equal(test_object.size, 'hello world.'.size)

    # Check crc wrong case.
    assert_raises Aliyun::OSS::CrcInconsistentError do
      @bucket.put_object(key, :init_crc => 1) do |content|
        content << 'hello world.'
      end
    end
  ensure
    @bucket.delete_object(key)
  end

  def test_append_object
    skip unless TestConf.creds[:upload_crc_enable]
    key = get_key('append_file')

    # Check crc status
    assert(@bucket.upload_crc_enable)

    # Check $key object doesn't exist.
    test_object = @bucket.get_object(key) rescue 0
    @bucket.delete_object(key) if test_object.size

    # Create a append object to oss with a string.
    position = @bucket.append_object(key, 0, :init_crc => 0) do |content|
      content << 'hello world.'
    end
    test_object = @bucket.get_object(key)
    assert_equal(test_object.size, 'hello world.'.size)

    # Append a test file to oss $key object.
    @bucket.append_object(key, position, {:init_crc => test_object.headers[:x_oss_hash_crc64ecma], :file => @@test_file.path})
    test_object = @bucket.get_object(key)
    assert_equal(test_object.size, 'hello world.'.size + (10 * 1024 * 1024))

    # No crc check when init_crc is nil
    position = @bucket.append_object(key, test_object.size) do |content|
      content << 'hello world.'
    end
    test_object = @bucket.get_object(key)
    assert_equal(test_object.size, 'hello world.'.size * 2 + (10 * 1024 * 1024))

    # Check crc wrong case.
    assert_raises Aliyun::OSS::CrcInconsistentError do
      position = @bucket.append_object(key, test_object.size, :init_crc => 0) do |content|
        content << 'hello world.'
      end
    end

    # Check crc wrong case.
    test_object = @bucket.get_object(key)
    assert_raises Aliyun::OSS::CrcInconsistentError do
      @bucket.append_object(key, test_object.size, {:init_crc => 0, :file => @@test_file.path})
    end
  ensure
    @bucket.delete_object(key)
  end

  def test_upload_object
    skip unless TestConf.creds[:upload_crc_enable]
    key = get_key('upload_file')

    # Check crc status
    assert(@bucket.upload_crc_enable)
    @bucket.resumable_upload(key, @@test_file.path, :cpt_file => "#{@@test_file.path}.cpt", threads: 2, :part_size => 1024 * 1024)

    test_object = @bucket.get_object(key)
    assert_equal(test_object.size, (10 * 1024 * 1024))

  ensure
    @bucket.delete_object(key)
  end

  def test_get_small_object
    skip unless TestConf.creds[:download_crc_enable]

    # Check crc status
    assert(@bucket.download_crc_enable)

    # Put a string to oss.
    key = get_key('get_small_object')
    @bucket.put_object(key) do |content|
      content << 'hello world.'
    end
    temp_buf = ""
    test_object = @bucket.get_object(key) { |c| temp_buf << c }
    assert_equal(test_object.size, 'hello world.'.size)

    # Check crc wrong case.
    assert_raises Aliyun::OSS::CrcInconsistentError do
      @bucket.get_object(key, {:init_crc => 1}) { |c| temp_buf << c }
    end
  ensure
    @bucket.delete_object(key)
  end

  def test_get_large_object
    skip unless TestConf.creds[:download_crc_enable]

    # Check crc status
    assert(@bucket.download_crc_enable)

    # put a test file with 10MB random bytes to oss for testing get.
    key = get_key('get_file')
    @bucket.put_object(key, :file => @@test_file.path)

    get_temp_file = Tempfile.new('oss_ruby_sdk_test_crc_get')
    test_object = @bucket.get_object(key, {:file => get_temp_file})
    assert_equal(test_object.size, 10 * 1024 * 1024)

    # Check crc wrong case.
    assert_raises Aliyun::OSS::CrcInconsistentError do
      @bucket.get_object(key, {:file => get_temp_file, :init_crc => 1})
    end
  ensure
    get_temp_file.unlink unless get_temp_file.nil?
    @bucket.delete_object(key)
  end

end
