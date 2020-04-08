require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/match_requires_with_includes'

RSpec.describe RuboCop::Cop::MatchRequiresWithIncludes do
  include CopHelper

  let(:missing_metadata_presentation_helper) do
    "Included 'VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers' but need to require 'presenters/mixins/metadata_presentation_helpers'"
  end

  let(:missing_sub_resource) do
    "Included 'SubResource' but need to require 'controllers/v3/mixins/sub_resource'"
  end

  subject(:cop) { RuboCop::Cop::MatchRequiresWithIncludes.new(RuboCop::Config.new({})) }

  it 'registers an offense if MetadataPresentationHelpers is included without requiring it', focus: true do
    inspect_source(<<~RUBY)
      require 'cows'
      module M
      class C
      include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers
      end
      end
    RUBY

    expect(cop.offenses.size).to eq(1)
    expect(cop.messages).to eq([missing_metadata_presentation_helper])
  end

  it 'does not register an offense if metadata_presentation_helpers required' do
    inspect_source(<<~RUBY)
      require 'presenters/mixins/metadata_presentation_helpers'
      module M
      class C
      include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers
      end
      end
    RUBY

    expect(cop.offenses.size).to eq(0)
  end

  it 'registers an offense if SubResource is included without requiring it', focus: true do
    inspect_source(<<~RUBY)
      require 'cows'
      module M
      class C
      include SubResource
      end
      end
    RUBY

    expect(cop.offenses.size).to eq(1)
    expect(cop.messages).to eq([missing_sub_resource])
  end

  it 'does not register an offense if metadata_presentation_helpers required' do
    inspect_source(<<~RUBY)
      require 'controllers/v3/mixins/sub_resource'
      module M
      class C
      include SubResource
      end
      end
    RUBY

    expect(cop.offenses.size).to eq(0)
  end

  it 'finds multiple offences', focus: true do
    inspect_source(<<~RUBY)
      require 'cows'
      module M
      class C
      include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers
      include SubResource
      end
      end
    RUBY
    expect(cop.offenses.size).to eq(2)
    expect(cop.messages).to match_array([missing_metadata_presentation_helper, missing_sub_resource])
  end
end
