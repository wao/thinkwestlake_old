require_relative '../../test_helper'
require 'thinwestlake'

class TestProject < Minitest::Test
    context "a simple project with only gid and aid" do
        setup do
            @gid = "info.thinkmore"
            @aid = "simple"
            @root = ThinWestLake::project @gid, @aid
        end

        should "access project with root" do
            assert_equal @gid.to_sym, @root.gid
            assert_equal @aid.to_sym, @root.aid
        end
    end

    context "a node with a boolean option simple" do
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

    context "a node with a enum option simple" do
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

    context "a node with a node property named n1 which define a boolean simple" do
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

    context "project with extensions" do
        should "support android" do
            root = ThinWestLake::project "android", "android", "1.0" do
                android
            end

            root.configure
            root.generate(ThinWestLake::DumpFileMgr.new)
        end
    end
    
    context "a project" do
        should "support generate file in path" do
            root = ThinWestLake::project "android", "android", "1.0"
            filepath = "/testproject/fakedir"
            root.twlpath( Pathname.new( filepath ) )

            filemgr = MiniTest::Mock.new
            filemgr.expect( :mkdir, nil, [filepath] )
            filemgr.expect( :write_file, nil, [filepath + "/pom.xml"] )

            root.configure
            root.generate(filemgr)
        end

        should "support generate module file in path" do
            root = ThinWestLake::project "android", "android", "1.0"
            filepath = "/testproject/fakedir"
            root.twlpath( Pathname.new( filepath ) )


            root.configure

            root.pom(:root).mymodule( "m1", ThinWestLake::Maven::Pom.new( :m1, :m1, "1.0" ) )
            root.pom(:root).mymodule( "m2", ThinWestLake::Maven::Pom.new( :m2, :m2, "1.0" ) )

            filemgr = MiniTest::Mock.new
            filemgr.expect( :mkdir, nil, [filepath] )
            filemgr.expect( :write_file, nil, [filepath + "/pom.xml"] )
            filemgr.expect( :mkdir, nil, [filepath + "/m1" ] )
            filemgr.expect( :write_file, nil, [filepath + "/m1/pom.xml"] )
            filemgr.expect( :mkdir, nil, [filepath + "/m2" ] )
            filemgr.expect( :write_file, nil, [filepath + "/m2/pom.xml"] )

            root.generate(filemgr)
        end

        should "support not generate submodule files if pass nil as pom" do
            root = ThinWestLake::project "android", "android", "1.0"
            filepath = "/testproject/fakedir"
            root.twlpath( Pathname.new( filepath ) )

            filemgr = MiniTest::Mock.new
            filemgr.expect( :mkdir, nil, [filepath] )
            filemgr.expect( :write_file, nil, [filepath + "/pom.xml"] )

            root.configure
            root.pom(:root).mymodule( "m1", nil )
            root.pom(:root).mymodule( "m2", nil )
            root.generate(filemgr)
        end
    end
end
