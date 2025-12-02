require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require_relative 'config'

class TestContentType < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)

    @types = {
      "html" => "text/html",
      "js" => "application/javascript",
      "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "xltx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.template",
      "potx" => "application/vnd.openxmlformats-officedocument.presentationml.template",
      "ppsx" => "application/vnd.openxmlformats-officedocument.presentationml.slideshow",
      "pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      "sldx" => "application/vnd.openxmlformats-officedocument.presentationml.slide",
      "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "dotx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.template",
      "xlam" => "application/vnd.ms-excel.addin.macroEnabled.12",
      "xlsb" => "application/vnd.ms-excel.sheet.binary.macroEnabled.12",
      "apk" => "application/vnd.android.package-archive",
      "" => "application/octet-stream"
    }

    @prefix = "tests/content_type/"
  end

  def get_key(p, k)
    "#{@prefix}#{p}obj" + (k.empty? ? "" : ".#{k}")
  end

  def test_type_from_key
    @types.each do |k, v|
      key = get_key('from_key', k)
      @bucket.put_object(key)
      assert_equal v, @bucket.get_object(key).headers[:content_type]

      copy_key = get_key('copy.from_key', k)
      @bucket.copy_object(key, copy_key)
      assert_equal v, @bucket.get_object(copy_key).headers[:content_type]

      append_key = get_key('append.from_key', k)
      @bucket.append_object(append_key, 0)
      assert_equal v, @bucket.get_object(append_key).headers[:content_type]
    end
  end

  def test_type_from_file
    @types.each do |k, v|
      upload_file = "/tmp/upload_file"
      upload_file += ".#{k}" unless k.empty?
      `touch #{upload_file}`

      key = get_key('from_file', k)
      @bucket.put_object(key, :file => upload_file)
      assert_equal v, @bucket.get_object(key).headers[:content_type]

      append_key = get_key('append.from_file', k)
      @bucket.append_object(append_key, 0, :file => upload_file)
      assert_equal v, @bucket.get_object(append_key).headers[:content_type]

      multipart_key = get_key('multipart.from_file', k)
      @bucket.resumable_upload(multipart_key, upload_file)
      assert_equal v, @bucket.get_object(multipart_key).headers[:content_type]
    end
  end

  def test_type_from_user
    @types.each do |k, v|
      upload_file = "/tmp/upload_file.html"
      `touch #{upload_file}`

      key = get_key('from_user', k)
      @bucket.put_object(key, :file => upload_file, :content_type => v)
      assert_equal v, @bucket.get_object(key).headers[:content_type]

      copy_key = get_key('copy.from_user', k)
      @bucket.copy_object(key, copy_key, :content_type => v)
      assert_equal v, @bucket.get_object(copy_key).headers[:content_type]

      append_key = get_key('append.from_user', k)
      @bucket.append_object(append_key, 0, :file => upload_file, :content_type => v)
      assert_equal v, @bucket.get_object(append_key).headers[:content_type]

      multipart_key = get_key('multipart.from_file', k)
      @bucket.resumable_upload(multipart_key, upload_file, :content_type => v)
      assert_equal v, @bucket.get_object(multipart_key).headers[:content_type]
    end
  end
end
