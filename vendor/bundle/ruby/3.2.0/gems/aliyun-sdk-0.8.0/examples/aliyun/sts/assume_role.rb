# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/sts'

Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.sts.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))
client = Aliyun::STS::Client.new(
  :access_key_id => conf['access_key_id'],
  :access_key_secret => conf['access_key_secret'])

# 辅助打印函数
def demo(msg)
  puts "######### #{msg} ########"
  puts
  yield
  puts "-------------------------"
  puts
end

token = client.assume_role(
  'acs:ram::52352:role/aliyunosstokengeneratorrole', 'app-1')

demo "Assume role" do
  begin
    token = client.assume_role(
      'acs:ram::52352:role/aliyunosstokengeneratorrole', 'app-1')

    puts "Credentials for session: #{token.session_name}"
    puts "access key id: #{token.access_key_id}"
    puts "access key secret: #{token.access_key_secret}"
    puts "security token: #{token.security_token}"
    puts "expiration at: #{token.expiration}"
  rescue => e
    puts "AssumeRole failed: #{e.message}"
  end
end

demo "Assume role with policy" do
  begin
    policy = Aliyun::STS::Policy.new
    policy.allow(
      ['oss:Get*', 'oss:PutObject'],
      ['acs:oss:*:*:my-bucket', 'acs:oss:*:*:my-bucket/*'])

    token = client.assume_role(
      'acs:ram::52352:role/aliyunosstokengeneratorrole', 'app-2', policy, 900)

    puts "Credentials for session: #{token.session_name}"
    puts "access key id: #{token.access_key_id}"
    puts "access key secret: #{token.access_key_secret}"
    puts "security token: #{token.security_token}"
    puts "expiration at: #{token.expiration}"
  rescue => e
    puts "AssumeRole failed: #{e.message}"
  end
end
