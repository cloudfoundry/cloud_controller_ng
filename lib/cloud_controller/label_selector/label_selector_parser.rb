require 'cloud_controller/label_selector/label_selector_lexer'

module VCAP::CloudController
  class LabelSelectorNode
    attr_accessor :operator, :name, :values

    def initialize(name, operator=nil)
      @name = name
      @operator = operator
      @values = []
    end

    def add(value)
      @values << value
    end

    def generate
      LabelSelectorRequirement.new(key: @name,
        operator: operator,
        values: @values,
      )
    end
  end

  class LabelSelectorParseError < RuntimeError
    def initialize(msg, input=nil, token=nil)
      if input && token
        msg +=  %/, got "#{show_token_state(input, token)}"/
      end
      super(msg)
    end

    private

    def show_token_state(input, tok)
      parts = []
      if tok[2] > 0
        start_part = input[0...tok[2]]
        if start_part.size > 30
          start_part = '...' + start_part[-27..-1]
        end
        parts << start_part
      end
      parts << "<<#{tok[1]}>>"
      if tok[2] + tok[1].size < input.size
        end_part = input[(tok[2] + tok[1].size)..-1]
        if end_part.size > 30
          end_part = end_part[0..27] + '...'
        end
        parts << end_part
      end
      parts.join('')
    end
  end

  class LabelSelectorParser
    attr_accessor :requirements, :errors

    # rubocop:disable Metrics/MethodLength
    def initialize
      @action_table = {
        at_start: {
          word: proc {
            @node = LabelSelectorNode.new(@token[1])
            @state = :has_key
          },
          not_op: :has_not_op,
          not_equal: "a key or '!' not followed by '='",
          default: "a key or '!'",
        },
        has_not_op: {
          word: proc {
            @nodes << LabelSelectorNode.new(@token[1], :not_exists)
            @state = :expecting_comma_or_eof
          },
          default: 'a key',
        },
        has_key: {
          equal: proc do
            @node.operator = @token[0]
            @state = :expect_value
          end,
          not_equal: proc  do
            @node.operator = @token[0]
            @state = :expect_value
          end,
          word: proc {
            if ['in', 'notin'].member?(@token[1])
              @node.operator = @token[1].to_sym
              @state = :expecting_open_paren
            else
              raise LabelSelectorParseError.new("expecting a ',', operator, or end", @input, @token)
            end
          },
          comma: proc {
            @node.operator = :exists
            @nodes << @node
            @state = :at_start
          },
          eof: proc {
            @node.operator = :exists
            @nodes << @node
            @done = true
          },
          default: "a ',', operator, or end",
        },
        expect_value: {
          word: proc {
            @node.values << @token[1]
            @nodes << @node
            @state = :expecting_comma_or_eof
          },
          default: 'a value',
        },
        expecting_open_paren: {
          open_paren: :expecting_set_value,
          default: "a '('",
        },
        expecting_set_value: {
          word: proc {
            @node.values << @token[1]
            @state = :expecting_comma_or_close_paren
          },
          default: 'a value',
        },
        expecting_comma_or_close_paren: {
          comma: :expecting_set_value,
          close_paren: proc {
            @nodes << @node
            @state = :expecting_comma_or_eof
          },
          default: "a ',' or ')'",
        },
        expecting_comma_or_eof: {
          comma: :at_start,
          eof: proc { @done = true },
          default: "a ',' or end"
        },
      }
    end
    # rubocop:enable Metrics/MethodLength

    def parse(input)
      @nodes = []
      @requirements = []
      @errors = []
      raise LabelSelectorParseError.new('empty label selector not allowed') if input.empty?

      @input = input

      tokens = LabelSelectorLexer.new.scan(input)
      bad_token = tokens.find { |tok| tok[0] == :error }
      if bad_token
        raise LabelSelectorParseError.new('disallowed character(s)', input, bad_token)
      end

      tokens = tokens.reject { |tok| tok[0] == :space } + [[:eof, '', input.size],]

      @state = :at_start
      @done = false
      tokens.each do |tok|
        @token = tok
        entry = @action_table[@state]
        if !entry
          raise Exception.new("internal error: Can't find an entry for #{token.inspect} at state #{@state}")
        end

        if !entry.key?(tok[0])
          action = entry[:default]
          raise LabelSelectorParseError.new("expecting #{entry[:default]}", input, tok) if action.nil?
        else
          action = entry[tok[0]]
        end

        case action
        when Symbol
          @state = action
        when Proc
          action.call
          break if @done
        when String
          raise LabelSelectorParseError.new("expecting #{action}", input, tok)
        else
          raise LabelSelectorParseError.new('internal error: unexpected input', input, tok)
        end
      end

      if !@done
        raise LabelSelectorParseError.new('Expecting completion of the selector, hit the end')
      end

      @requirements = @nodes.map(&:generate)
      true
    rescue LabelSelectorParseError => ex
      @errors << ex.message
      false
    end
  end
end
