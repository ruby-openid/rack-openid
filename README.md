# Rack::OpenID

Provides a more HTTPish API around the ruby-openid library.

# Usage

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


TODO
====
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
[🖐contributors]: https://github.com/VitalConnectInc/rack-openid2/graphs/contributors
[🖐contributors-img]: https://contrib.rocks/image?repo=VitalConnectInc/rack-openid2

## 📄 License

The gem is available as open source under the terms of
the [MIT License][📄license] [![License: MIT][📄license-img]][📄license-ref].
See [LICENSE.txt][📄license] for the official [Copyright Notice][📄copyright-notice-explainer].

[comment]: <> ( 📄 LEGAL LINKS )

[📄copyright-notice-explainer]: https://opensource.stackexchange.com/questions/5778/why-do-licenses-such-as-the-mit-license-specify-a-single-year
[📄license]: LICENSE.txt
[📄license-ref]: https://opensource.org/licenses/MIT
[📄license-img]: https://img.shields.io/badge/License-MIT-green.svg
