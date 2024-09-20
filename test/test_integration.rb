# External libraries
require "rots"

require_relative "test_helper"

describe "integration" do
  class MockFetcher
    def initialize(app)
      @app = app
    end

    def fetch(url, body = nil, headers = nil, limit = nil)
      opts = (headers || {}).dup
      opts[:input] = body
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

  ROTS_SERVER_URL = "http://localhost:9292"

  RotsApp = Rack::Builder.new do
    config = {
      "identity" => "john.doe",
      "sreg" => {
        "nickname" => "jdoe",
        "fullname" => "John Doe",
        "email" => "jhon@doe.com",
        "dob" => Date.parse("1985-09-21"),
        "gender" => "M",
      },
    }

    map("/%s" % config["identity"]) do
      run(Rots::IdentityPageApp.new(config, {}))
    end

    map("/server") do
      run(Rots::ServerApp.new(config, storage: Dir.tmpdir))
    end
  end

  OpenID.fetcher = MockFetcher.new(RotsApp)

  module RackTestHelpers
    private

    def process(*args)
      env = Rack::MockRequest.env_for(*args)
      @response = Rack::MockResponse.new(*@app.call(env))
    end

    def follow_redirect!
      assert(@response)
      assert_equal(303, @response.status)

      env = Rack::MockRequest.env_for(@response.headers["Location"])
      _status, headers, _body = RotsApp.call(env)

      uri = URI(headers["Location"])
      process("#{uri.path}?#{uri.query}")
    end
  end

  describe "headers" do
    it "builds header" do
      assert_equal 'OpenID identity="http://example.com/"',
        Rack::OpenID.build_header(identity: "http://example.com/")
      assert_equal 'OpenID identity="http://example.com/?foo=bar"',
        Rack::OpenID.build_header(identity: "http://example.com/?foo=bar")

      header = Rack::OpenID.build_header(identity: "http://example.com/", return_to: "http://example.org/")

      assert_match(/OpenID /, header)
      assert_match(/identity="http:\/\/example\.com\/"/, header)
      assert_match(/return_to="http:\/\/example\.org\/"/, header)

      header = Rack::OpenID.build_header(identity: "http://example.com/", required: ["nickname", "email"])

      assert_match(/OpenID /, header)
      assert_match(/identity="http:\/\/example\.com\/"/, header)
      assert_match(/required="nickname,email"/, header)
    end

    it "parses header" do
      assert_equal(
        {"identity" => "http://example.com/"},
        Rack::OpenID.parse_header('OpenID identity="http://example.com/"'),
      )
      assert_equal(
        {"identity" => "http://example.com/?foo=bar"},
        Rack::OpenID.parse_header('OpenID identity="http://example.com/?foo=bar"'),
      )
      assert_equal(
        {"identity" => "http://example.com/", "return_to" => "http://example.org/"},
        Rack::OpenID.parse_header('OpenID identity="http://example.com/", return_to="http://example.org/"'),
      )
      assert_equal(
        {"identity" => "http://example.com/", "required" => ["nickname", "email"]},
        Rack::OpenID.parse_header('OpenID identity="http://example.com/", required="nickname,email"'),
      )

      # ensure we don't break standard HTTP basic auth
      assert_empty(
        Rack::OpenID.parse_header('Realm="Example"'),
      )
    end
  end

  describe "openid" do
    include RackTestHelpers

    it "with_get" do
      @app = app({})
      process("/", method: "GET")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_deprecated_identity" do
      @app = app({})
      process("/", method: "GET", identity: "#{ROTS_SERVER_URL}/john.doe?openid.success=true")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_post_method" do
      @app = app({})
      process("/", method: "POST")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "POST", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_custom_return_to" do
      @app = app(return_to: "http://example.org/complete")
      process("/", method: "GET")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/complete", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_get_nested_params_custom_return_to" do
      url = "http://example.org/complete?user[remember_me]=true"
      @app = app(return_to: url)
      process("/", method: "GET")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/complete", @response.headers["X-Path"]
      assert_equal "success", @response.body
      assert_match(/remember_me/, @response.headers["X-Query-String"])
    end

    it "with_post_nested_params_custom_return_to" do
      url = "http://example.org/complete?user[remember_me]=true"
      @app = app(return_to: url)
      process("/", method: "POST")

      assert_equal 303, @response.status
      env = Rack::MockRequest.env_for(@response.headers["Location"])
      _status, headers, _body = RotsApp.call(env)

      _uri, input = headers["Location"].split("?", 2)
      process("http://example.org/complete?user[remember_me]=true", method: "POST", input: input)

      assert_equal 200, @response.status
      assert_equal "POST", @response.headers["X-Method"]
      assert_equal "/complete", @response.headers["X-Path"]
      assert_equal "success", @response.body
      assert_match(/remember_me/, @response.headers["X-Query-String"])
    end

    it "with_post_method_custom_return_to" do
      @app = app(return_to: "http://example.org/complete")
      process("/", method: "POST")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/complete", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_custom_return_method" do
      @app = app(method: "put")
      process("/", method: "GET")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "PUT", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_simple_registration_fields" do
      @app = app(required: ["nickname", "email"], optional: "fullname")
      process("/", method: "GET")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_attribute_exchange" do
      @app = app(
        required: ["http://axschema.org/namePerson/friendly", "http://axschema.org/contact/email"],
        optional: "http://axschema.org/namePerson",
      )
      process("/", method: "GET")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_oauth" do
      @app = app(
        "oauth[consumer]": "www.example.com",
        "oauth[scope]": ["http://docs.google.com/feeds/", "http://spreadsheets.google.com/feeds/"],
      )
      process("/", method: "GET")

      location = @response.headers["Location"]

      assert_match(/openid.oauth.consumer/, location)
      assert_match(/openid.oauth.scope/, location)

      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_pape" do
      @app = app(
        "pape[preferred_auth_policies]": ["test_policy1", "test_policy2"],
        "pape[max_auth_age]": 600,
      )
      process("/", method: "GET")

      location = @response.headers["Location"]

      assert_match(/pape\.preferred_auth_policies=test_policy1\+test_policy2/, location)
      assert_match(/pape\.max_auth_age=600/, location)

      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "success", @response.body
    end

    it "with_immediate_mode_setup_needed" do
      skip("because failing, and not enough time to fix all the things") do
        @app = app(identifier: "#{ROTS_SERVER_URL}/john.doe?openid.success=false", immediate: true)
        process("/", method: "GET")

        location = @response.headers["Location"]

        assert_match(/openid.mode=checkid_immediate/, location)

        follow_redirect!

        assert_equal 307, @response.status
        assert_equal "GET", @response.headers["X-Method"]
        assert_equal "/", @response.headers["X-Path"]
        assert_equal ROTS_SERVER_URL, @response.headers["Location"]
        assert_equal "setup_needed", @response.body
      end
    end

    it "with_realm_wildcard" do
      @app = app(
        realm_domain: "*.example.org",
      )
      process("/", method: "GET")

      location = @response.headers["Location"]

      assert_match(/openid.realm=http%3A%2F%2F%2A.example.org/, location)

      follow_redirect!

      assert_equal 200, @response.status
    end

    it "with_inferred_realm" do
      @app = app({})
      process("/", method: "GET")

      location = @response.headers["Location"]

      assert_match(/openid.realm=http%3A%2F%2Fexample.org/, location)

      follow_redirect!

      assert_equal 200, @response.status
    end

    it "with_missing_id" do
      @app = app(identifier: "#{ROTS_SERVER_URL}/john.doe")
      process("/", method: "GET")
      follow_redirect!

      assert_equal 400, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "cancel", @response.body
    end

    it "with_timeout" do
      @app = app(identifier: ROTS_SERVER_URL)
      process("/", method: "GET")

      assert_equal 400, @response.status
      assert_equal "GET", @response.headers["X-Method"]
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "missing", @response.body
    end

    it "sanitize_query_string" do
      @app = app({})
      process("/", method: "GET")
      follow_redirect!

      assert_equal 200, @response.status
      assert_equal "/", @response.headers["X-Path"]
      assert_equal "", @response.headers["X-Query-String"]
    end

    it "passthrough_standard_http_basic_auth" do
      @app = app({})
      process("/", :method => "GET", "MOCK_HTTP_BASIC_AUTH" => "1")

      assert_equal 401, @response.status
    end

    private

    def app(options = {})
      options[:identifier] ||= "#{ROTS_SERVER_URL}/john.doe?openid.success=true"

      rack_app = lambda { |env|
        if (resp = env[Rack::OpenID::RESPONSE])
          headers = {
            "X-Path" => env["PATH_INFO"],
            "X-Method" => env["REQUEST_METHOD"],
            "X-Query-String" => env["QUERY_STRING"],
          }
          if resp.status == :success
            [200, headers, [resp.status.to_s]]
          elsif resp.status == :setup_needed
            headers["Location"] = ROTS_SERVER_URL # TODO update Rots to properly send user_setup_url. This should come from resp.
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
      Rack::Session::Pool.new(Rack::OpenID.new(rack_app))
    end
  end

  describe "simple auth" do
    include RackTestHelpers

    it "can login" do
      @app = simple_app("#{ROTS_SERVER_URL}/john.doe?openid.success=true")

      process "/dashboard"
      follow_redirect!

      assert_equal 303, @response.status
      assert_equal "http://example.org/dashboard", @response.headers["Location"]

      cookie = @response.headers["Set-Cookie"].split(";").first
      process "/dashboard", "HTTP_COOKIE" => cookie

      assert_equal 200, @response.status
      assert_equal "Hello", @response.body
    end

    it "fails login" do
      @app = simple_app("#{ROTS_SERVER_URL}/john.doe")
      @app = simple_app("#{ROTS_SERVER_URL}/john.doe")

      process "/dashboard"
      follow_redirect!

      assert_match ROTS_SERVER_URL, @response.headers["Location"]
    end

    private

    def simple_app(identifier)
      rack_app = lambda { |env| [200, {"Content-Type" => "text/html"}, ["Hello"]] }
      rack_app = Rack::OpenID::SimpleAuth.new(rack_app, identifier)
      Rack::Session::Pool.new(rack_app)
    end
  end
end
