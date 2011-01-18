require 'minitest/autorun'
require 'minitest/spec'
require 'net/http'

require 'rack'
require 'rack/openid'
require 'rack/openid/simple_auth'

log = Logger.new(STDOUT)
log.level = Logger::WARN
OpenID::Util.logger = log

class MockFetcher
  def initialize(app)
    @app = app
  end

  def fetch(url, body = nil, headers = nil, limit = nil)
    opts = (headers || {}).dup
    opts[:input]  = body
    opts[:method] = "POST" if body
    env = Rack::MockRequest.env_for(url, opts)

    status, headers, body = @app.call(env)

    buf = []
    buf << "HTTP/1.1 #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}"
    headers.each { |header, value| buf << "#{header}: #{value}" }
    buf << ""
    body.each { |part| buf << part }

    io = Net::BufferedIO.new(StringIO.new(buf.join("\n")))
    res = Net::HTTPResponse.read_new(io)
    res.reading_body(io, true) {}
    OpenID::HTTPResponse._from_net_response(res, url)
  end
end

RotsServerUrl = 'http://localhost:9292'

RotsApp = Rack::Builder.new do
  require 'rots'

  config = {
    'identity' => 'john.doe',
    'sreg' => {
      'nickname' => 'jdoe',
      'fullname' => 'John Doe',
      'email' => 'jhon@doe.com',
      'dob' => Date.parse('1985-09-21'),
      'gender' => 'M'
    }
  }

  map("/%s" % config['identity']) do
    run Rots::IdentityPageApp.new(config, {})
  end

  map '/server' do
    run Rots::ServerApp.new(config, :storage => Dir.tmpdir)
  end
end

OpenID.fetcher = MockFetcher.new(RotsApp)

describe "headers" do
  def test_build_header
    assert_equal 'OpenID identity="http://example.com/"',
      Rack::OpenID.build_header(:identity => "http://example.com/")
    assert_equal 'OpenID identity="http://example.com/?foo=bar"',
      Rack::OpenID.build_header(:identity => "http://example.com/?foo=bar")

    header = Rack::OpenID.build_header(:identity => "http://example.com/", :return_to => "http://example.org/")
    assert_match(/OpenID /, header)
    assert_match(/identity="http:\/\/example\.com\/"/, header)
    assert_match(/return_to="http:\/\/example\.org\/"/, header)

    header = Rack::OpenID.build_header(:identity => "http://example.com/", :required => ["nickname", "email"])
    assert_match(/OpenID /, header)
    assert_match(/identity="http:\/\/example\.com\/"/, header)
    assert_match(/required="nickname,email"/, header)
  end

  def test_parse_header
    assert_equal({"identity" => "http://example.com/"},
      Rack::OpenID.parse_header('OpenID identity="http://example.com/"'))
    assert_equal({"identity" => "http://example.com/?foo=bar"},
      Rack::OpenID.parse_header('OpenID identity="http://example.com/?foo=bar"'))
    assert_equal({"identity" => "http://example.com/", "return_to" => "http://example.org/"},
      Rack::OpenID.parse_header('OpenID identity="http://example.com/", return_to="http://example.org/"'))
    assert_equal({"identity" => "http://example.com/", "required" => ["nickname", "email"]},
      Rack::OpenID.parse_header('OpenID identity="http://example.com/", required="nickname,email"'))

    # ensure we don't break standard HTTP basic auth
    assert_equal({},
      Rack::OpenID.parse_header('Realm="Example"'))
  end
end

module RackTestHelpers
  private

  def process(*args)
    env = Rack::MockRequest.env_for(*args)
    @response = Rack::MockResponse.new(*@app.call(env))
  end

  def follow_redirect!
    assert @response
    assert_equal 303, @response.status

    env = Rack::MockRequest.env_for(@response.headers['Location'])
    _status, headers, _body = RotsApp.call(env)

    uri = URI(headers['Location'])
    process("#{uri.path}?#{uri.query}")
  end
end

describe "openid" do
  include RackTestHelpers

  def test_with_get
    @app = app
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_deprecated_identity
    @app = app
    process('/', :method => 'GET', :identity => "#{RotsServerUrl}/john.doe?openid.success=true")
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_post_method
    @app = app
    process('/', :method => 'POST')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'POST', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_custom_return_to
    @app = app(:return_to => 'http://example.org/complete')
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/complete', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_get_nested_params_custom_return_to
    url = 'http://example.org/complete?user[remember_me]=true'
    @app = app(:return_to => url)
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/complete', @response.headers['X-Path']
    assert_equal 'success', @response.body
    assert_match(/remember_me/, @response.headers['X-Query-String'])
  end

  def test_with_post_nested_params_custom_return_to
    url = 'http://example.org/complete?user[remember_me]=true'
    @app = app(:return_to => url)
    process('/', :method => 'POST')

    assert_equal 303, @response.status
    env = Rack::MockRequest.env_for(@response.headers['Location'])
    _status, headers, _body = RotsApp.call(env)

    _uri, input = headers['Location'].split('?', 2)
    process("http://example.org/complete?user[remember_me]=true", :method => 'POST', :input => input)

    assert_equal 200, @response.status
    assert_equal 'POST', @response.headers['X-Method']
    assert_equal '/complete', @response.headers['X-Path']
    assert_equal 'success', @response.body
    assert_match(/remember_me/, @response.headers['X-Query-String'])
  end

  def test_with_post_method_custom_return_to
    @app = app(:return_to => 'http://example.org/complete')
    process('/', :method => 'POST')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/complete', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_custom_return_method
    @app = app(:method => 'put')
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'PUT', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_simple_registration_fields
    @app = app(:required => ['nickname', 'email'], :optional => 'fullname')
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_attribute_exchange
    @app = app(
      :required => ['http://axschema.org/namePerson/friendly', 'http://axschema.org/contact/email'],
      :optional => 'http://axschema.org/namePerson')
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_oauth
    @app = app(
      :'oauth[consumer]' => 'www.example.com',
      :'oauth[scope]' => ['http://docs.google.com/feeds/', 'http://spreadsheets.google.com/feeds/']
    )
    process('/', :method => 'GET')

    location = @response.headers['Location']
    assert_match(/openid.oauth.consumer/, location)
    assert_match(/openid.oauth.scope/, location)

    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end
  
  def test_with_pape
    @app = app(
      :'pape[preferred_auth_policies]' => ['test_policy1', 'test_policy2'],
      :'pape[max_auth_age]' => 600
    )
    process('/', :method => 'GET')
    
    location = @response.headers['Location']
    assert_match(/pape\.preferred_auth_policies=test_policy1\+test_policy2/, location)
    assert_match(/pape\.max_auth_age=600/, location)
    
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_immediate_mode_setup_needed
    skip do
      @app = app(:identifier => "#{RotsServerUrl}/john.doe?openid.success=false", :immediate => true)
      process('/', :method => 'GET')

      location = @response.headers['Location']
      assert_match(/openid.mode=checkid_immediate/, location)

      follow_redirect!
      assert_equal 307, @response.status
      assert_equal 'GET', @response.headers['X-Method']
      assert_equal '/', @response.headers['X-Path']
      assert_equal RotsServerUrl, @response.headers['Location']
      assert_equal 'setup_needed', @response.body
    end
  end

  def test_with_realm_wildcard
    @app = app(
      :realm_domain => "*.example.org"
    )
    process('/', :method => 'GET')

    location = @response.headers['Location']
    assert_match(/openid.realm=http%3A%2F%2F%2A.example.org/, location)

    follow_redirect!
    assert_equal 200, @response.status
  end

  def test_with_inferred_realm
    @app = app
    process('/', :method => 'GET')

    location = @response.headers['Location']
    assert_match(/openid.realm=http%3A%2F%2Fexample.org/, location)

    follow_redirect!
    assert_equal 200, @response.status
  end

  def test_with_ui_mode
    @app = app(
      :'ui[mode]' => 'popup'
    )
    process('/', :method => 'GET')

    location = @response.headers['Location']
    assert_match(/openid.ui.mode/, location)

    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_ui_icon
    @app = app(
      :'ui[icon]' => true
    )
    process('/', :method => 'GET')

    location = @response.headers['Location']
    assert_match(/openid.ui.icon/, location)

    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_ui_lang
    @app = app(
      :'ui[lang]' => 'ja-JP'
    )
    process('/', :method => 'GET')

    location = @response.headers['Location']
    assert_match(/openid.ui.lang/, location)

    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_missing_id
    @app = app(:identifier => "#{RotsServerUrl}/john.doe")
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 400, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'cancel', @response.body
  end

  def test_with_timeout
    @app = app(:identifier => RotsServerUrl)
    process('/', :method => "GET")
    assert_equal 400, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'missing', @response.body
  end

  def test_sanitize_query_string
    @app = app
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal '/', @response.headers['X-Path']
    assert_equal '', @response.headers['X-Query-String']
  end

  def test_passthrough_standard_http_basic_auth
    @app = app
    process('/', :method => 'GET', "MOCK_HTTP_BASIC_AUTH" => '1')
    assert_equal 401, @response.status
  end

  private

  def app(options = {})
    options[:identifier] ||= "#{RotsServerUrl}/john.doe?openid.success=true"

    app = lambda { |env|
      if resp = env[Rack::OpenID::RESPONSE]
        headers = {
          'X-Path' => env['PATH_INFO'],
          'X-Method' => env['REQUEST_METHOD'],
          'X-Query-String' => env['QUERY_STRING']
        }
        if resp.status == :success
          [200, headers, [resp.status.to_s]]
        elsif resp.status == :setup_needed
          headers['Location'] = RotsServerUrl #TODO update Rots to properly send user_setup_url. This should come from resp.
          [307, headers, [resp.status.to_s]]
        else
          [400, headers, [resp.status.to_s]]
        end
      elsif env["MOCK_HTTP_BASIC_AUTH"]
        [401, {Rack::OpenID::AUTHENTICATE_HEADER => 'Realm="Example"'}, []]
      else
        [401, {Rack::OpenID::AUTHENTICATE_HEADER => Rack::OpenID.build_header(options)}, []]
      end
    }
    Rack::Session::Pool.new(Rack::OpenID.new(app))
  end
end

describe "simple auth" do
  include RackTestHelpers

  def test_successful_login
    @app = app "#{RotsServerUrl}/john.doe?openid.success=true"

    process '/dashboard'
    follow_redirect!

    assert_equal 303, @response.status
    assert_equal 'http://example.org/dashboard', @response.headers['Location']

    cookie = @response.headers['Set-Cookie'].split(';').first
    process '/dashboard', 'HTTP_COOKIE' => cookie
    assert_equal 200, @response.status
    assert_equal 'Hello', @response.body
  end

  def test_failed_login
    @app = app "#{RotsServerUrl}/john.doe"

    process '/dashboard'
    follow_redirect!
    assert_match RotsServerUrl, @response.headers['Location']
  end

  private

  def app(identifier)
    app = lambda { |env| [200, {'Content-Type' => 'text/html'}, ['Hello']] }
    app = Rack::OpenID::SimpleAuth.new(app, identifier)
    Rack::Session::Pool.new(app)
  end
end
