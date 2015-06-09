require 'minitest/autorun'
require 'shoulda/context'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new # spec-like progress
