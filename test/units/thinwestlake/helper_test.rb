#!/usr/bin/env ruby

require_relative "../../test_helper"
require 'thinwestlake/helper'

class TestHelper < Minitest::Test
    context "a attr_rw helper" do
        should "enable class to add method to read and write" do
            classa = Class.new do
                include ThinWestLake::AttrRw

                attr_rw :a
            end

            obj = classa.new

            assert_respond_to( obj, :a )
            assert_nil obj.a
            obj.a(1)
            assert_equal 1, obj.a
        end
    end
end
