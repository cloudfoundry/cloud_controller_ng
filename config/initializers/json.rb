require 'bigdecimal'

# Override BigDecimal's 'as_json' to return self so that Oj can handle it according to its configuration.
# By default, ActiveSupport encodes BigDecimal as a string which we do not want.
class BigDecimal
  def as_json(*_args)
    self
  end
end

module CCInitializers
  def self.json(_cc_config)
    Oj.default_options = {
      time_format: :ruby,            # Encode Time/DateTime in Ruby-style string format
      mode: :rails,                  # Rails-compatible JSON behavior
      bigdecimal_load: :bigdecimal,  # Decode JSON decimals as BigDecimal
      compat_bigdecimal: true,       # Required in :rails mode to avoid Float decoding
      bigdecimal_as_decimal: true    # Encode BigDecimal as JSON number (not string)
    }.freeze

    Oj.optimize_rails                # Use Oj for Rails JSON encoding/decoding
  end
end
