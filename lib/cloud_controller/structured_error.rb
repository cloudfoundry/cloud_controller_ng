class StructuredError < StandardError
  attr_reader :error, :code, :hash_to_merge

  def initialize(msg, options={})
    super(msg)
    @error = options[:error]
    @code = options[:code] || 10001

    @hash_to_merge = options[:hash_to_merge]
  end

  def to_h
    hash = {
      'code' => code,
      'description' => message,
      'types' => self.class.ancestors.map(&:name) - Exception.ancestors.map(&:name),
      'backtrace' => backtrace
    }

    hash['source'] = error if error
    if hash_to_merge
      hash.merge!(hash_to_merge)
    end

    hash
  end
end
