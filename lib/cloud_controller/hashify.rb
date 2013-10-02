#
# Helper methods for turning things into hashes.
#
module Hashify
  def self.exception(exception)
    {
      'description' => exception.message,
      'types' => types(exception),
      'backtrace' => exception.backtrace,
    }
  end

  def self.types(exception)
    exception.class.ancestors.map{|cls| demodulize(cls)} - StructuredError.ancestors.map{|cls| demodulize(cls)}
  end

  private

  def self.demodulize(cls)
    cls.name.split('::').last
  end
end
