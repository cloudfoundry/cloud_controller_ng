# Allowy - the simple authorization for Ruby (and/or Rails)

Allowy is the authorization library that doesn't enforce tight DSL on you.
It is very simple yet powerful.

## Why another one?

I've been using really great [cancan](https://github.com/ryanb/cancan) gem by Ryan Bates for a long time.
It does its job amazingly well.

Allowy is basically the result of refactoring the CanCan Ability class. I then extracted it into a gem.

CanCan doesn't work very well for me when Ability definitions grow above 20 lines or so:

- it becomes **really hard to track down** why something was (or not) allowed.
- **DSL enforces** you to use ActiveRecord-like scopes or blocks. It gets harder to maintain.
- The Ability class contains **all the definitions for everything**. Hard to test, hard to maintain unless you carefully refactor it.
- Implicit permission - CanCan tries to be very smart (and is indeed) using aliases such as `:manage` but it makes even harder to understand it.
- Implicit permission - you can use any symbol to check permissions. `:love_people` will do, even if you never defined it.
- A little bit **tight to ORM**. When using with database such as neo4j, some small-ish things don't work. So I prefer to be explicit.
- **Testing** an ability for a single class often depends on too many others.
- **Refacoring** of the abilities feels like rolling your own authorization library.

So I decided to put up allowy to solve those issue for me.

[Allowy](https://github.com/dnagir/allowy) better suites if you want more control over your authorization. It is inspired by CanCan, but was implemented with simplicity and explicitness in mind.


# Install

Add it to your Rails application's `Gemfile`:

```ruby
gem 'allowy'
```

Then `bundle install`.

Or use `allowy` gem as usually.

# Usage

I will be assuming a CMS-like system in the examples below.
The `Page` class may be ActiveRecord, Mongoid or any other model of your choice. Doesn't matter.


## Minimal setup

You define a set of permissions per class.
If you want to safeguard `Page` class then define `PageAccess` class:

```ruby
class PageAccess
  include Allowy::AccessControl

  # This will allow you to ask: `can? :view, page`
  # The truthy result of this function will grant access, otherwise not.
  def view?(page)
    page and page.published?
  end

  def edit?(page)
    page and page.wiki?
  end
end

# Then, in rails controller/view, you would use it:
can? :view, page
cannot? :edit, page
authorize! :view, page # raises Allowy::AccessDenied if can?(:view, page) returns false
can? :love_people, page # Will raise NoMethodError because `love_people` is not defined on the Access Control class
```

## Context

You can access current user, request data etc using the `context` method.
In Rails, the context is set to the current controller, so you have full access to it (not only the current user!).


```ruby
class PageAccess
  include Allowy::AccessControl

  def view?(page)
    return true if context.params[:hidden_hack_for_admin]
    context.user_signed_in? and page.published?
  end
end
```

If you want to change the context in Rails then just override it in the controller or globally in the `ApplicationController`.
The only requirement for the context is that it should mix-in the `Allowy::Context` module.

```ruby
class CmsContext < Hash
  include Allowy::Context
end

class PagesController < ApplicationController
  def allowy_context
    CmsContext.new {realy: 'anything', can_be: 'here', even: params}
  end
end
```


## Customising access class

The "access" class, by convention, will be determined by the class of the original object plus the "Access" suffix.
It may be a problem if you decorate the class using `draper` gem or using similar approach where the actual class name is different.

The version `0.3` has built-in support for the `draper` gem and it should "just work".

But additionally it provides a customisation option for you if you need that.

So if you need to change the access class for your object you need to do the following:


```ruby
# This will just work provided there's a PageAccess class
class PageDecorator < Draper::Decorator
end

class PageViewModel < SimpleDelegator
  # This will allow using PageViewModel as it would be just Page
  def self.source_class
    Page
  end
end

```

If you simply don't like the `Access` suffix, you can override it by passing the `access_suffix` option to the `Registry` class.
For example, in a typical Rails app you will need to override the `current_allowy` method on the `ApplicationController` like so:

```ruby
class ApplicationController < ActionController::Base
  def current_allowy
    @current_allowy ||= ::Allowy::Registry.new(allowy_context, access_suffix: 'Permission')
  end
end
```

The above will allow using `UserPermission` class name instead of `UserAccess`.

# Early termination

If you have a pre-condition for any permission checks you can abort more complex logic by
calling `deny!('my reason to deny')`.

For example:

```ruby
class PageAccess < DefaultAccess
  def view?(page)
    deny!(:no_user) unless current_user
    page and page.published? and domain_name =~ /^www\./i
  end
end
```

This is very similar to:

```ruby
class PageAccess < DefaultAccess
  def view?(page)
    return false unless current_user
    page and page.published? and domain_name =~ /^www\./i
  end
end
```

Except that additional information on the exception will be available when calling `authorize!`.

This information is available from the ` Allowy::AccessDenied#payload`.


## More comprehensive example

You probably have multiple classes that you want to protect.
I recommend creating your own base class or module to provide common context and maybe some utility methods:

```ruby
class DefaultAccess
  include Allowy::AccessControl
  delegate :current_user,    :to => :context
  delegate :current_company, :to => :context

  def domain_name
    context.request.host
  end
end
```

Then you can create multiple access control classes:

```ruby
class PageAccess < DefaultAccess
  # can? :view, page
  def view?(page)
    page and page.published? and domain_name =~ /^www\./i
  end

  # can? :edit, page
  def edit?(page)
    view?(page) and page.wiki? # Notice how we can reuse other definitions!
  end

  # can? :create, WikiPage
  def create?(page_class)
    # We can do something with WikiPage here if we need to
    return false if page_class.count >= 2 # only 2 wiki pages allowed
    # but can just ignore it and authorize based on current context only
    current_user and current_user.admin?
  end

  # can? :search, Page, 'Ruby rocks!'
  def search?(clazz, phrase)
    # Apart from context, we can require to pass additional parameters
    create?(Page) and (phrase || '').match /rocks/i
  end
end
```

In your controller:

```ruby
class PagesController < ApplicationController
  def show
    @page = Page.find(params[:id])
    authorize! :view, @page # It will raise if declined
    # can?, cannot? can be used too
  end

  # Add this to the ApplicationController to handle it globally
  rescue_from Allowy::AccessDenied do |exception|
    logger.debug "Access denied on #{exception.action} #{exception.subject.inspect}"
    redirect_to new_user_session_url if no_access.payload == :no_user
    render('shared/no_permission', message: exception.message)
  end
end
```

In your views:

```haml
# app/views/pages/show.html.haml

%h1= @page.name
= link_to "Edit", edit_page_path if can? :edit, @page
```


# Testing with RSpec

To test the access control classes you can just instantiate those passing context as a parameter.
Most of the time you will stub out the context, so the test isolation is a piece of cake.

You need to `require 'allowy/rspec'`.
It will give you:

- `be_able_to` RSpec matcher;
-  `ignore_authorization!` macro for controller specs;
-  `should_authorize_for` method for controller specs (can **only** be used with `ignore_authorization!`).


```ruby
# spec/models/page_access.rb
# Example spec for the PageAccess
describe PageAccess do
  subject     { PageAccess.new double(current_user: User.new.or_whatever) }
  let(:page)  { Page.new }

  describe "#view" do
    it { should_not be_able_to :view, page }

    # Or without the matcher
    it "should not allow" do
      subject.view?(page).should be_false
    end

    context "I prefer RSpec contexts" do
      subject { PageAccess.new(stub(:current_user: user)).view?(page) }

      context "when logged in" do
        let(:user) { stub 'User' }
        context "and page is wiki" do
          before { page.stub(wiki?: true) }
          it { should be_true }
        end
        context "and page is not wiki" do
          before { page.stub(wiki?: false) }
          it { should be_false }
        end
      end

      context "when anonim" do
        let(:user) { nil }
        it { should be_false }
      end
    end

  end
end


# Example of a controller spec
describe PagesController do
  # This will always grant access, so you don't have to create too many objects
  # But make sure you test PageAccess separately as in the example above
  ignore_authorization! 

  it "will always allow no matter what" do
    post(:create).should be_success
  end

  it "checks the authorisation" do
    should_authorize_for(:create, page)
    post(:create)
  end

  it "checks the authorisation with plain RSpec if you don't like the macro" do
    allowy.should_receive(:authorize!).with(:create, page)
    post(:create)
  end
end

```

# Development


- Source hosted at [GitHub](https://github.com/dnagir/allowy)
- Report issues and feature requests to [GitHub Issues](https://github.com/dnagir/allowy/issues)
- Ping me on Twitter [@dnagir](https://twitter.com/#!/dnagir)


To start contributing (assuming you already cloned the repo in cd-d into it):

```bash
bundle install
# Now run the Ruby specs
bundle exec rspec spec/
```

Pull requests are very welcome, but please include the specs.
