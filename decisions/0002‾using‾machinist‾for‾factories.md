2: Using Machinist for Factories
================================

Date: 2019-03-22

Status
------

Accepted


Context
-------

[machinist][] is a ruby library that makes it easy to create objects for use in test.
[Factories tend to be preferable to fixtures][factories-not-fixtures].

We decided to try switching over from [machinist][] to [factory_bot][].
Our primary decision behind switching was because machinist is unmaintained.
The last commit to _master_ is from 2013. factory_bot is well maintained
and is very popular.

We had converted roughly a dozen factories over from machinist to factory_bot,
starting from the leaf nodes of our object graph.
As we moved to objects with associations,
we encountered increasing degrees of friction.

The differences in how [sequel][] and [active_record][] handle associations
mean that factory_bot was not well suited.
In active_record,
associations are created by placing a foreign key on one of the two records.
Specifically,
the record with the `belongs_to` contains the foreign key for the record with the `has_one`.
This means that any factory library can create the `has_one` record,
generate its primary key 'A',
then create the `belongs_to` record with a foreign key of 'A'.
In our usage of sequel,
some associations have mutual foreign keys on both of the two records.
So, a factory library has to create the first record,
generate its primary key 'A' with no association,
then create the second record with primary key 'B' and foreign key 'A',
then update the first record so that its foreign key is 'B'.
This "create-create-update" workflow is tricky (but possible) in factory_bot
and is clean in machinist.

```ruby
# machinist
AppModel.blueprint do
  name       { Sham.name }
  space      { Space.make }
  buildpack_lifecycle_data { BuildpackLifecycleDataModel.make(app: object.save) }
end

# factory_bot
FactoryBot.define do
  factory :app, aliases: [:app_model], class: VCAP::CloudController::AppModel do
    name

    transient do
      space
    end

    trait :buildpack do
      after(:create) do |app, evaluator|
        app.buildpack_lifecycle_data = create(:buildpack_lifecycle_data)
      end
    end

    trait :docker do
    end

    after(:create) do |app, evaluator|
      app.space = evaluator.space if evaluator.space
    end
  end
end
```

Decision
--------

We have reverted the conversion commits, remaining with machinist.
We will switch to a maintained fork of machinist.
(It turns out that other people use machinist too.)


Consequences
------------

New team members will have to learn machinist,
whereas rubyists would probably be familiar with factory_bot.

There will no longer be a state where both machinist and factory_bot are used while converting.

[machinist]: https://github.com/notahat/machinist
[factories-not-fixtures]: http://www.betterspecs.org/#factories
[factory_bot]: https://github.com/thoughtbot/factory_bot
