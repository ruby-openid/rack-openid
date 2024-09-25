require_relative "support/config"

describe "simple auth" do
  include Rots::Test::RackTestHelpers

  it "can login" do
    app = simple_app("#{Rots::Mocks::RotsServer::SERVER_URL}/john.doe?openid.success=true")
    mock_openid_request app, "/dashboard"
    follow_openid_redirect!(app)

    assert_equal 303, @response.status
    assert_equal "http://example.org/dashboard", @response.headers["Location"]

    cookie = @response.headers["Set-Cookie"].split(";").first
    mock_openid_request app, "/dashboard", "HTTP_COOKIE" => cookie

    assert_equal 200, @response.status
    assert_equal "Hello", @response.body
  end

  it "fails login" do
    app = simple_app("#{Rots::Mocks::RotsServer::SERVER_URL}/john.doe")

    mock_openid_request app, "/dashboard"
    follow_openid_redirect!(app)

    assert_match Rots::Mocks::RotsServer::SERVER_URL, @response.headers["Location"]
  end

  private

  def simple_app(identifier)
    rack_app = lambda { |env| [200, {"Content-Type" => "text/html"}, ["Hello"]] }
    rack_app = Rack::OpenID::SimpleAuth.new(rack_app, identifier)
    Rack::Session::Pool.new(rack_app)
  end
end
