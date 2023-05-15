# frozen_string_literal: true

require 'test_helper'

# Test of the whole gem featues
class NavigationTest < ActionDispatch::IntegrationTest
  def test_should_likeize
    assert_equal('first', 'first'.likeize)
    assert_equal('first%second', 'first second'.likeize)
    assert_equal('first%second', 'first      second'.likeize)
    assert_equal('first%second', 'first$%/(()$%second'.likeize)
    assert_equal('first%second%third', 'first second third'.likeize)
  end
end
