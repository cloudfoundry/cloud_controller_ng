module CCInitializers
  def self.feature_flag_overrides(cc_config)
    @logger ||= Steno.logger('cc.feature_flag_overrides')
    @logger.info("Initializing feature_flag_overrides: #{cc_config[:feature_flag_overrides]}")
    return unless cc_config[:feature_flag_overrides]

    VCAP::CloudController::FeatureFlag.override_default_flags(cc_config[:feature_flag_overrides])
  end
end
