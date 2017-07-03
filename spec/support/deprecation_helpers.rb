module DeprecationHelpers
  def it_should_be_removed(by:, explanation:)
    it 'is deprecated and should be removed' do
      skip 'Ignoring time bomb tests' if ENV['SKIP_TIME_BOMBS']
      if Date.today >= Date.parse(by)
        fail(explanation)
      end
    end
  end
end
