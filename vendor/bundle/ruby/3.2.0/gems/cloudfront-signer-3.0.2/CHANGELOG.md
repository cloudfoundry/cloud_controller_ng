# Change Log

## 3.0.2 / 2017-06-22

* Provides an option to URI escape the path before signing it. Issue and accepted PR from [@mynock](https://github.com/mynock)
* Replaces Fixnum with Integer for Ruby 2.4.1. Issue and accepted PR from [@scott-knight](https://github.com/scott-knight)

## 3.0.1 / 2017-01-20

* Supports signing frozen strings. Bug reported by [@alexandermayr](https://github.com/alexandermayr).

## 3.0.0 / 2015-03-14

* Renames namespace to `Aws`. Matches used by latest [https://github.com/aws/aws-sdk-ruby](https://github.com/aws/aws-sdk-ruby).
  Change proposed by [@tennantje](https://github.com/tennantje)
* Renames `sign` to `build_url` to better communicate method intent.

## 2.2.0 / 2015-04-29

* Accepted merge request from [@leonelgalan](https://github.com/leonelgalan) -
  `sign_params` method returns raw params to be used in urls or cookies.

## 2.1.2 / 2015-04-16

* Accepted merge request from [@tuvistavie](https://github.com/tuvistavie) -
  fixing custom policy bug.

## 2.1.1 / 2013-10-31

* Added changelog file
* Aceppted merge request from [@bullfight](https://github.com/bullfight),
  Refactored configuration to allow for key to be passed in directly.
