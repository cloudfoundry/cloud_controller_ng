#
# Helper methods for turning things into hashes.
#
module Hashify
  def self.exception(exception)
    {
      'description' => exception.message,
      'backtrace' => exception.backtrace,
    }
  end

  def self.demodulize(cls)
    cls.name.split('::').last
  end
end
