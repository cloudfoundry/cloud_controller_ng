require 'minitest/autorun'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require 'aliyun/oss'
require_relative 'config'

class TestResumable < Minitest::Test
  def setup
    Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
    client = Aliyun::OSS::Client.new(TestConf.creds)
    @bucket = client.get_bucket(TestConf.bucket)

    @prefix = 'tests/resumable/'
  end

  def get_key(k)
    @prefix + k
  end

  def random_string(n)
    (1...n).map { (65 + rand(26)).chr }.join + "\n"
  end

  def test_correctness
    key = get_key('resumable')
    # generate 10M random data
    File.open('/tmp/x', 'w') do |f|
      (10 * 1024).times { f.write(random_string(1024)) }
    end

    # clear checkpoints
    `rm -rf /tmp/x.cpt && rm -rf /tmp/y.cpt`

    @bucket.resumable_upload(key, '/tmp/x', :part_size => 100 * 1024)
    @bucket.resumable_download(key, '/tmp/y', :part_size => 100 * 1024)

    diff = `diff /tmp/x /tmp/y`
    assert diff.empty?, diff
  end
end
