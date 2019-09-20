module VCAP::CloudController
  class LabelSelectorLexer
    def initialize
      @token_types = [
        [:comma, ','],
        [:open_paren, '\\('],
        [:close_paren, '\\)'],
        [:space, '\\s+'],
        [:equal, '==?'],
        [:not_equal, '!='],
        [:not_op, '!'], # as in !foo<END> -- no label named foo
        [:word, '[-_.\w]+(?:/[-_.\w]+)?'],
        [:error, '.'],  # [^\w\(\)\s=?!]+
      ]
      @ptn = Regexp.new(@token_types.map { |t| "(#{t[1]})" }.join('|'))
    end

    def scan(input)
      @num_chars_read = 0
      input.scan(@ptn).map do |g|
        idx = g.find_index { |x| !x.nil? }
        tok = [@token_types[idx][0], g[idx], @num_chars_read]
        @num_chars_read += tok[1].size
        tok
      end
    end
  end
end
