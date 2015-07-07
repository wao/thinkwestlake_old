require_relative "../../test_helper.rb"

require 'thinwestlake'
require 'thinwestlake/loader'

include ThinWestLake

class LoaderTest < MiniTest::Test
    RES = Pathname.new( File.dirname( __FILE__ ) + "/../../res/loader" )

    context "a loader" do
        setup do
            @loader = Loader.new
            @filemgr = StoreFileMgr.new
        end

        should "load TWLFile in current twlpath" do
            project = @loader.load_current_twlfile( RES + "sub1" )
            assert_equal :sub1, project.gid
            assert_equal RES + "sub1", project.twlpath
        end

        should "load TWLFile in parent twlpath if current twlpath has no TWLFile" do
            project = @loader.load_current_twlfile( RES + "sub3" )
            assert_equal :parent, project.gid
            assert_equal RES, project.twlpath
        end

        should "load root if current TWLFile set has_parent" do
            @loader.load_all( RES + "sub1" )
            assert_equal :parent, @loader.parent.gid
            assert_equal RES, @loader.parent.twlpath
            assert_equal :sub1, @loader.current.gid
            assert_equal RES+"sub1", @loader.current.twlpath
        end

        should "load not load root if current TWLFile doesn't set has_parent" do
            @loader.load_all( RES + "sub2" )
            assert_nil @loader.parent
        end

        should "generate pom with parent node if has_parent is set" do
            @loader.load_all( RES + "sub1" )
            @loader.generate_all( @filemgr )
            
            #pp @filemgr.data
            doc = XmlDoc.new( @filemgr.data[ "/home/w19816/myprojects/android/thinwestlake/test/units/thinwestlake/../../res/loader/sub1/pom.xml" ] )
            assert_equal "sub1", doc.text( "/project/groupId" ) 
            assert_equal "parent", doc.text( "/project/parent/groupId" ) 
        end

        should "generate pom with moudle if children directoris contain TWLfile with has_parent" do
            @loader.load_all( RES + "sub1" )
            @loader.generate_all( @filemgr )
            
            #pp @filemgr.data
            doc = XmlDoc.new( @filemgr.data[ "/home/w19816/myprojects/android/thinwestlake/test/units/thinwestlake/../../res/loader/sub1/pom.xml" ] )
            assert_equal "sub1", doc.text( "/project/groupId" ) 
            assert_equal "sub11", doc.text( "/project/modules/module" ) 
        end

        should "generate parent pom with moudle if current set has_parent" do
            @loader.load_all( RES + "sub1" )
            @loader.generate_all( @filemgr )
            
            #pp @filemgr.data
            doc = XmlDoc.new( @filemgr.data[ "/home/w19816/myprojects/android/thinwestlake/test/units/thinwestlake/../../res/loader/pom.xml" ] )
            assert_equal "parent", doc.text( "/project/groupId" ) 
            assert_equal "sub1", doc.text( "/project/modules/module" ) 
        end
    end

end
