source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in thecore_backend_commons.gemspec.
gemspec

# The Rails line this suite runs on (Odoo #6089, ADR 0033): Rails 8.1, the only one CI tests.
# The gem itself keeps declaring Rails 7.2 (dual support, best effort): `RAILS_VERSION=7.2
# bundle update rails && RAILS_VERSION=7.2 bin/test` runs the same suite on 7.2.4 locally. Both lines are
# pinned because a fresh CI resolution otherwise drifts (Odoo #6088); minitest stays on 5, since
# Rails 7.2's test runner breaks on minitest 6.
if ENV["RAILS_VERSION"] == "7.2"
  gem "rails", "~> 7.2.4"
else
  gem "rails", "~> 8.1", ">= 8.1.4.1"
end
gem "minitest", "~> 5.25"

gem "pg"
gem "web-push", "~> 3.0"

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

# JUnit XML report in CI (test/support/junit_report.rb, only when JUNIT_REPORT_DIR is set).
gem "minitest-reporters", "~> 1.8"
