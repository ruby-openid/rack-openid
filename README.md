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

Authors
=======

[Joshua Peek](https://github.com/josh) original author

### [Contributors](https://github.com/grosser/rack-openid/contributors)
 - [Kenny Buckler](https://github.com/kbuckler)
 - [Mike Dillon](https://github.com/md5)
 - [Richard Wilson](https://github.com/Senjai)

[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>

