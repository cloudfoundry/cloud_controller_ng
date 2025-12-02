# DelayedJob Sequel Backend

[![Build Status](https://secure.travis-ci.org/TalentBox/delayed_job_sequel.png?branch=master)](http://travis-ci.org/TalentBox/delayed_job_sequel)
[![Code Climate](https://codeclimate.com/github/TalentBox/delayed_job_sequel.png)](https://codeclimate.com/github/TalentBox/delayed_job_sequel)

## Compatibility

This gem works on Ruby (MRI/CRuby) 1.9.3 and 2.0.x.

It's strongly recommended to use a Ruby >= 1.9.3 version.

## Installation

Add the gem to your Gemfile:

    gem 'talentbox-delayed_job_sequel'

Run `bundle install`.

Create an initializer to setup the DelayedJob backend:

```ruby
# config/initializers/delayed_job.rb

::Delayed::Worker.backend = :sequel
```

Create the table (using the sequel migration syntax):

    create_table :delayed_jobs do
      primary_key :id
      Integer :priority, :default => 0
      Integer :attempts, :default => 0
      String  :handler, :text => true
      String  :last_error, :text => true
      Time    :run_at
      Time    :locked_at
      Time    :failed_at
      String  :locked_by
      String  :queue
      Time    :created_at
      Time    :updated_at
      index   [:priority, :run_at]
    end

## Contributors

Improvements has been made by those awesome contributors:

* Mark Rushakoff (@mark-rushakoff)
* Phan Le
* Tim Labeeuw
* James Goodhouse (@jamesgoodhouse)
* Lyle Franklin (@ljfranklin)
* Florent Piteau (@flop)

## How to contribute

If you find what looks like a bug:

* Search the [mailing list](http://groups.google.com/group/delayed_job) to see if anyone else had the same issue.
* Check the [GitHub issue tracker](http://github.com/TalentBox/delayed_job_sequel/issues/) to see if anyone else has reported issue.
* If you don't see anything, create an issue with information on how to reproduce it.

If you want to contribute an enhancement or a fix:

* Fork the project on github.
* Make your changes with tests.
* Commit the changes without making changes to the Rakefile or any other files that aren't related to your enhancement or fix
* Send a pull request.
