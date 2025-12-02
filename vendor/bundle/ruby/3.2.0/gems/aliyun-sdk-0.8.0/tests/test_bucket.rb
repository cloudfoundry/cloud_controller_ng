require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require 'time'
require_relative 'config'

class TestBucket < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    @client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket_name = TestConf.bucket + Time.now.to_i.to_s
    @client.create_bucket(@bucket_name)
    @bucket = @client.get_bucket(@bucket_name)
  end

  def teardown
    @client.delete_bucket(@bucket_name)
  end

  def test_bucket_versioning
    ret = @bucket.versioning
    assert_nil ret.status

    @bucket.versioning =  Aliyun::OSS::BucketVersioning.new(:status => 'Enabled')
    ret = @bucket.versioning
    assert_equal 'Enabled', ret.status

    @bucket.versioning =  Aliyun::OSS::BucketVersioning.new(:status => 'Suspended')
    ret = @bucket.versioning
    assert_equal 'Suspended', ret.status

  end

  def test_bucket_encryption

    begin
      ret = @bucket.encryption
      assert_raises "should not here"
    rescue => exception
    end  

    @bucket.encryption =  Aliyun::OSS::BucketEncryption.new(
      :enable => true,
      :sse_algorithm => 'KMS')
    ret = @bucket.encryption
    assert_equal 'KMS', ret.sse_algorithm
    assert_nil ret.kms_master_key_id

    @bucket.encryption =  Aliyun::OSS::BucketEncryption.new(
      :enable => true,
      :sse_algorithm => 'KMS',
      :kms_master_key_id => 'kms-id')
    ret = @bucket.encryption
    assert_equal 'KMS', ret.sse_algorithm
    assert_equal 'kms-id', ret.kms_master_key_id

    @bucket.encryption =  Aliyun::OSS::BucketEncryption.new(
      :enable => true,
      :sse_algorithm => 'AES256')
    ret = @bucket.encryption
    assert_equal 'AES256', ret.sse_algorithm
    assert_nil ret.kms_master_key_id

    @bucket.encryption =  Aliyun::OSS::BucketEncryption.new(
      :enable => false)
    begin
      ret = @bucket.encryption
      assert_raises "should not here"
    rescue => exception
    end  
  end
end
