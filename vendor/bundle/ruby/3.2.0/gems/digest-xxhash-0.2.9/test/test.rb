require 'csv'
require 'minitest/autorun'

# To show more verbose messages, install minitest-reporters and uncomment the
# following lines:
#
# require "minitest/reporters"
# Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

TEST_DIR = File.dirname(__FILE__)
require File.join(TEST_DIR, %w{ .. lib digest xxhash })

def get_repeated_0x00_to_0xff(length)
  hex = (0..0xff).to_a.map{ |e| sprintf "%2x", e }.join
  str = [hex].pack('H*')
  cycles = (Float(length) / str.size).ceil
  [str].cycle(cycles).to_a.join[0...length]
end

[Digest::XXH32, Digest::XXH64, Digest::XXH3_64bits, Digest::XXH3_128bits].each do |klass|
  describe klass do
    it "produces correct types of digest outputs" do
      _(klass.digest("")).must_be_instance_of String
      _(klass.hexdigest("")).must_be_instance_of String
      _(klass.idigest("")).must_be_kind_of Integer
      _(klass.new.digest("")).must_be_instance_of String
      _(klass.new.hexdigest("")).must_be_instance_of String
      _(klass.new.idigest("")).must_be_kind_of Integer
    end

    it "produces similar output with its digest, hexdigest and idigest methods" do
      digest = klass.digest("abcd")
      _(klass.new.digest("abcd")).must_equal digest
      _(klass.new.update("ab").update("cd").digest).must_equal digest
      _(klass.new.update("ab").update("cd").digest!).must_equal digest
      _(klass.new.reset.update("ab").update("cd").digest!).must_equal digest

      hexdigest = klass.hexdigest("abcd")
      _(klass.new.hexdigest("abcd")).must_equal hexdigest
      _(klass.new.update("ab").update("cd").hexdigest).must_equal hexdigest
      _(klass.new.update("ab").update("cd").hexdigest!).must_equal hexdigest
      _(klass.new.reset.update("ab").update("cd").hexdigest!).must_equal hexdigest

      idigest = klass.idigest("abcd")
      _(klass.new.idigest("abcd")).must_equal idigest
      _(klass.new.update("ab").update("cd").idigest).must_equal idigest
      _(klass.new.update("ab").update("cd").idigest!).must_equal idigest
      _(klass.new.reset.update("ab").update("cd").idigest!).must_equal idigest

      digest_hex = digest.unpack('H*').pop
      _(hexdigest).must_equal digest_hex

      idigest_hex = "%08x" % idigest
      _(hexdigest).must_equal idigest_hex
    end
  end
end

CSV.foreach(File.join(TEST_DIR, 'test.vectors'), col_sep: '|').with_index(1) do |csv, line_num|
  algo, msg_method, msg_length, seed_type, seed_or_secret, sum = csv

  case msg_method
  when 'null'
    msg = ''
  when '0x00_to_0xff'
    msg = get_repeated_0x00_to_0xff(msg_length.to_i)
  else
    raise "Invalid message generation method specified in test.vectors:#{line_num}: #{msg_method}"
  end

  case algo
  when '32'
    klass = Digest::XXH32
  when '64'
    klass = Digest::XXH64
  when 'xxh3-64'
    klass = Digest::XXH3_64bits
  when 'xxh3-128'
    klass = Digest::XXH3_128bits
  else
    raise "Invalid algorithm specified in test.vectors:#{line_num}: #{algo}"
  end

  case seed_type
  when 'seed'
    describe klass do
      describe "using #{msg_method}(#{msg_length}) as message generator, and #{seed_or_secret} as seed" do
        it "should produce #{sum}" do
          _(klass.hexdigest(msg, seed_or_secret)).must_equal sum
        end
        it "should produce #{sum} using reset-first strategy" do
          _(klass.new.reset(seed_or_secret).update(msg).hexdigest).must_equal sum
        end
        it "should produce #{sum} using reset-first strategy with an external hex-to-int converter" do
          _(klass.new.reset(seed_or_secret.to_i(16)).update(msg).hexdigest).must_equal sum
        end
      end
    end
  when 'secret'
    describe klass do
      describe "using #{msg_method}(#{msg_length}) as message generator, and #{seed_or_secret} as secret" do
        it "should produce #{sum}" do
          secret_str = [seed_or_secret].pack('H*')
          _(klass.new.reset_with_secret(secret_str).update(msg).hexdigest).must_equal sum
        end
      end
    end
  else
    raise "Invalid seed type specified in test.vectors:#{line_num}: #{seed_type}"
  end
end

describe Digest::XXHash::XXH3_SECRET_SIZE_MIN do
  it "should be 136" do
    # Documentation should be updated to reflect the new value if this fails.
    _(Digest::XXHash::XXH3_SECRET_SIZE_MIN).must_equal 136
  end
end

describe Digest::XXHash do
  it "must have VERSION constant" do
    _(Digest::XXHash.constants).must_include :VERSION
  end
end
