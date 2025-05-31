# Rack::OpenID

[![Version](https://img.shields.io/gem/v/rack-openid2.svg)](https://rubygems.org/gems/rack-openid2)
[![Downloads Today](https://img.shields.io/gem/rd/rack-openid2.svg)](https://github.com/oauth-xx/rack-openid2)
[![CI Supported Build][🚎s-wfi]][🚎s-wf]
[![CI Unsupported Build][🚎us-wfi]][🚎us-wf]
[![CI Style Build][🚎st-wfi]][🚎st-wf]
[![CI Coverage Build][🚎cov-wfi]][🚎cov-wf]
[![CI Heads Build][🚎hd-wfi]][🚎hd-wf]

-----

[![Liberapay Patrons][⛳liberapay-img]][⛳liberapay]
[![Sponsor Me on Github][🖇sponsor-img]][🖇sponsor]
[![Polar Shield][🖇polar-img]][🖇polar]
[![Donate to my FLOSS or refugee efforts at ko-fi.com][🖇kofi-img]][🖇kofi]
[![Donate to my FLOSS or refugee efforts using Patreon][🖇patreon-img]][🖇patreon]

[🚎s-wf]: https://github.com/oauth-xx/rack-openid2/actions/workflows/supported.yml
[🚎s-wfi]: https://github.com/oauth-xx/rack-openid2/actions/workflows/supported.yml/badge.svg
[🚎us-wf]: https://github.com/oauth-xx/rack-openid2/actions/workflows/unsupported.yml
[🚎us-wfi]: https://github.com/oauth-xx/rack-openid2/actions/workflows/unsupported.yml/badge.svg
[🚎st-wf]: https://github.com/oauth-xx/rack-openid2/actions/workflows/style.yml
[🚎st-wfi]: https://github.com/oauth-xx/rack-openid2/actions/workflows/style.yml/badge.svg
[🚎cov-wf]: https://github.com/oauth-xx/rack-openid2/actions/workflows/coverage.yml
[🚎cov-wfi]: https://github.com/oauth-xx/rack-openid2/actions/workflows/coverage.yml/badge.svg
[🚎hd-wf]: https://github.com/oauth-xx/rack-openid2/actions/workflows/heads.yml
[🚎hd-wfi]: https://github.com/oauth-xx/rack-openid2/actions/workflows/heads.yml/badge.svg

[⛳liberapay-img]: https://img.shields.io/liberapay/patrons/pboling.svg?logo=liberapay
[⛳liberapay]: https://liberapay.com/pboling/donate
[🖇sponsor-img]: https://img.shields.io/badge/Sponsor_Me!-pboling.svg?style=social&logo=github
[🖇sponsor]: https://github.com/sponsors/pboling
[🖇polar-img]: https://polar.sh/embed/seeks-funding-shield.svg?org=pboling
[🖇polar]: https://polar.sh/pboling
[🖇kofi-img]: https://img.shields.io/badge/buy%20me%20coffee-donate-yellow.svg
[🖇kofi]: https://ko-fi.com/O5O86SNP4
[🖇patreon-img]: https://img.shields.io/badge/patreon-donate-yellow.svg
[🖇patreon]: https://patreon.com/galtzo

Provides a more HTTP-ish API around the ruby-openid library.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rack-openid2

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rack-openid2

## Usage

You trigger an OpenID request similar to HTTP authentication. From your app, return a "401 Unauthorized" and a "WWW-Authenticate" header with the identifier you would like to validate.

On competition, the OpenID response is automatically verified and assigned to `env["rack.openid.response"]`.

### Rack Example

```Ruby
MyApp = lambda do |env|
  if resp = env["rack.openid.response"]
    case resp.status
    when :success
      ...
    when :failure
      ...
    else
      [401, {"WWW-Authenticate" => 'OpenID identifier="http://example.com/"'}, []]
    end
  end
end

use Rack::OpenID
run MyApp
```

### Sinatra Example

```Ruby
# Session needs to be before Rack::OpenID
use Rack::Session::Cookie

require 'rack/openid'
use Rack::OpenID

get '/login' do
  erb :login
end

post '/login' do
  if resp = request.env["rack.openid.response"]
    if resp.status == :success
      "Welcome: #{resp.display_identifier}"
    else
      "Error: #{resp.status}"
    end
  else
    headers 'WWW-Authenticate' => Rack::OpenID.build_header(
      :identifier => params["openid_identifier"]
    )
    throw :halt, [401, 'got openid?']
  end
end

enable :inline_templates

__END__

@@ login
<form action="/login" method="post">
  <p>
    <label for="openid_identifier">OpenID:</label>
    <input id="openid_identifier" name="openid_identifier" type="text" />
  </p>

  <p>
    <input name="commit" type="submit" value="Sign in" />
  </p>
</form>
```

## General Info

| Primary Namespace | `Rack::OpenID`                                                                                                                                                                                                                                                                                                                                                                                                                                        |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| gem name          | [ruby-openid2](https://rubygems.org/gems/rack-openid2)                                                                                                                                                                                                                                                                                                                                                                                                |
| code triage       | [![Open Source Helpers](https://www.codetriage.com/oauth-xx/rack-openid2/badges/users.svg)](https://www.codetriage.com/oauth-xx/rack-openid2)                                                                                                                                                                                                                                                                                                         |
| documentation     | [on Github.com][homepage],  [on rubydoc.info][documentation]                                                                                                                                                                                                                                                                                                                                                                                             |
| expert support    | [![Get help on Codementor](https://cdn.codementor.io/badges/get_help_github.svg)](https://www.codementor.io/peterboling?utm_source=github&utm_medium=button&utm_term=peterboling&utm_campaign=github)                                                                                                                                                                                                                                                 |
| `...` 💖          | [![Liberapay Patrons][⛳liberapay-img]][⛳liberapay] [![Sponsor Me][🖇sponsor-img]][🖇sponsor] [![Follow Me on LinkedIn][🖇linkedin-img]][🖇linkedin] [![Find Me on WellFound:][✌️wellfound-img]][✌️wellfound] [![Find Me on CrunchBase][💲crunchbase-img]][💲crunchbase] [![My LinkTree][🌳linktree-img]][🌳linktree] [![Follow Me on Ruby.Social][🐘ruby-mast-img]][🐘ruby-mast] [![Tweet @ Peter][🐦tweet-img]][🐦tweet] [💻][coderme] [🌏][aboutme] |

<!-- 7️⃣ spread 💖 -->
[🐦tweet-img]: https://img.shields.io/twitter/follow/galtzo.svg?style=social&label=Follow%20%40galtzo
[🐦tweet]: http://twitter.com/galtzo
[🚎blog]: http://www.railsbling.com/tags/rack-openid2/
[🚎blog-img]: https://img.shields.io/badge/blog-railsbling-brightgreen.svg?style=flat
[🖇linkedin]: http://www.linkedin.com/in/peterboling
[🖇linkedin-img]: https://img.shields.io/badge/PeterBoling-blue?style=plastic&logo=linkedin
[✌️wellfound]: https://angel.co/u/peter-boling
[✌️wellfound-img]: https://img.shields.io/badge/peter--boling-orange?style=plastic&logo=wellfound
[💲crunchbase]: https://www.crunchbase.com/person/peter-boling
[💲crunchbase-img]: https://img.shields.io/badge/peter--boling-purple?style=plastic&logo=crunchbase
[🐘ruby-mast]: https://ruby.social/@galtzo
[🐘ruby-mast-img]: https://img.shields.io/mastodon/follow/109447111526622197?domain=https%3A%2F%2Fruby.social&style=plastic&logo=mastodon&label=Ruby%20%40galtzo
[🌳linktree]: https://linktr.ee/galtzo
[🌳linktree-img]: https://img.shields.io/badge/galtzo-purple?style=plastic&logo=linktree
[documentation]: https://rubydoc.info/github/oauth-xx/rack-openid2
[homepage]: https://github.com/oauth-xx/rack-openid2

<!-- Maintainer Contact Links -->
[aboutme]: https://about.me/peter.boling
[coderme]: https://coderwall.com/Peter%20Boling

## TODO

- 1 failing test (skipped)
- rewrite tests with minitest/spec

## 🌈 Contributors

Current maintainer(s):

- [Peter Boling](https://github.com/pboling)

Special thanks to:
- [Joshua Peek](https://github.com/josh) author of original `rack-openid`
- [Michael Grosser](http://grosser.it) maintainer of original `rack-openid`

and contributors to original `rack-openid`:
- [Kenny Buckler](https://github.com/kbuckler)
- [Mike Dillon](https://github.com/md5)
- [Richard Wilson](https://github.com/Senjai)

[![Contributors][🖐contributors-img]][🖐contributors]

Made with [contributors-img][🖐contrib-rocks].

[🖐contrib-rocks]: https://contrib.rocks
[🖐contributors]: https://github.com/oauth-xx/rack-openid2/graphs/contributors
[🖐contributors-img]: https://contrib.rocks/image?repo=oauth-xx/rack-openid2

## 🪇 Code of Conduct

Everyone interacting in this project's codebases, issue trackers,
chat rooms and mailing lists is expected to follow the [code of conduct][🪇conduct].

[🪇conduct]: CODE_OF_CONDUCT.md

## 📌 Versioning

This Library adheres to [Semantic Versioning 2.0.0][📌semver].
Violations of this scheme should be reported as bugs.
Specifically, if a minor or patch version is released that breaks backward compatibility,
a new version should be immediately released that restores compatibility.
Breaking changes to the public API will only be introduced with new major versions.

To get a better understanding of how SemVer is intended to work over a project's lifetime,
read this article from the creator of SemVer:

- ["Major Version Numbers are Not Sacred"][📌major-versions-not-sacred]

As a result of this policy, you can (and should) specify a dependency on these libraries using
the [Pessimistic Version Constraint][📌pvc] with two digits of precision.

For example:

```ruby
spec.add_dependency("rack-openid2", "~> 2.0")
```

See [CHANGELOG.md][📌changelog] for list of releases.

[comment]: <> ( 📌 VERSIONING LINKS )

[📌pvc]: http://guides.rubygems.org/patterns/#pessimistic-version-constraint
[📌semver]: http://semver.org/
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📌changelog]: CHANGELOG.md

## 📄 License

The gem is available as open source under the terms of
the [MIT License][📄license] [![License: MIT][📄license-img]][📄license-ref].

See [LICENSE.txt][📄license] for the official [Copyright Notice][📄copyright-notice-explainer].

[comment]: <> ( 📄 LEGAL LINKS )

[📄copyright-notice-explainer]: https://opensource.stackexchange.com/questions/5778/why-do-licenses-such-as-the-mit-license-specify-a-single-year
[📄license]: LICENSE.txt
[📄license-ref]: https://opensource.org/licenses/MIT
[📄license-img]: https://img.shields.io/badge/License-MIT-green.svg

## 🤑 One more thing

You made it to the bottom of the page, so perhaps you'll indulge me for another 20 seconds. I maintain many dozens of gems, including this one, because I want Ruby to be a great place for people to solve problems, big and small. Please consider supporting my efforts via the giant yellow link below, or one of the others at the head of this README.

[![Buy me a latte][🖇buyme-img]][🖇buyme]

[🖇buyme-img]: https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20latte&emoji=&slug=pboling&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff
[🖇buyme]: https://www.buymeacoffee.com/pboling
