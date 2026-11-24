# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
# The WebSocket JWT is signed with SECRET_KEY_BASE (no credentials in the dummy app): CI has none,
# so a run without it gets a throwaway one, as the host apps' CI does.
require "securerandom"
ENV["SECRET_KEY_BASE"] ||= SecureRandom.hex(64)

require_relative "../test/dummy/config/environment"
require "rails/test_help"
require_relative "support/junit_report"

ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end
