require_relative '../test_helper'
require 'thinwestlake'

class TestProject < Minitest::Test
    context "a simple project with only gid and aid" do
        setup do
            @gid = "info.thinkmore"
            @aid = "simple"
            ThinWestLake.project @gid, @aid
        end

        teardown do
            ThinWestLake.reset
        end

        should "access project with root" do
            assert_equal @gid.to_sym, ThinWestLake.root.gid
            assert_equal @aid.to_sym, ThinWestLake.root.aid
        end

        should "raise a exception with second project definition" do
            assert_raises ArgumentError do
                ThinWestLake.project "a", "b"
            end
        end
    end

    context "node with a boolean option simple" do
       setup do
           @node_class = Class.new( ThinWestLake::Node ) do
               boolean :simple
           end

           @node = @node_class.new
       end

       should "has simple method can set boolean as true" do
           @node.simple
           assert @node.prop(:simple)
       end
       
       should "has no_simple method can set boolean as false" do
           @node.no_simple
           assert !@node.prop(:simple)
       end
    end

    context "node with a enum option simple" do
        setup do
           @node_class = Class.new( ThinWestLake::Node ) do
               enum :simple, [ :a, :b, :c]
           end

           @node = @node_class.new
        end

        should "accept :a" do
            @node.simple :a
            assert_equal :a, @node.prop(:simple)
        end

        should "not accept :b" do
            assert_raises ArgumentError do
                @node.simple :d
            end
        end
    end

    context "node with a node property named n1 which define a boolean simple" do
        setup do
           @node_class = Class.new( ThinWestLake::Node ) do
               node :n1 do
                   boolean :simple
               end
           end

           @node = @node_class.new
        end

        should "using simple in n1 can be a true boolean" do
           @node.n1 do
               simple
            end

            assert @node.node(:n1).prop(:simple)
        end
    end
    
    context "pom object" do
        setup do
            @pom = ThinWestLake::Maven::Pom.new( "info.thinkmore", "testpkg", "1.0.0" )
        end

        should "write xml" do
            puts @pom.to_xml.target!
        end

        should "can define plugins" do
            @pom.plugin( "gid:aid" ) do
                version( 100 )
            end

            puts @pom.to_xml.target!
        end
    end
end
