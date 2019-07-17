module VCAP
  module SemverValidator
    # regex credit: [DavidFichtmueller](https://github.com/DavidFichtmueller)
    # (https://github.com/semver/semver/issues/232#issuecomment-405596809)
    SEMVER_REGEX =
      /
            ^
            (?<major>0|[1-9]\d*)\.
            (?<minor>0|[1-9]\d*)\.
            (?<patch>0|[1-9]\d*)
            (?:-
              (?<prerelease>
                (?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)
                (?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*
              )
            )?
            (?:\+
              (?<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*)
            )?
            $
      /x.freeze

    class << self
      def valid?(version)
        SEMVER_REGEX.match?(version.to_s)
      end
    end
  end
end
