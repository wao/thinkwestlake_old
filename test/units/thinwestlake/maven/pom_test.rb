require_relative "../../../test_helper"

require 'thinwestlake/maven/pom'
require 'rexml/document'

include ThinWestLake::Maven

class TestMavenPom < Minitest::Test
    context "a PomBlock" do
        setup do 
            @pomblock = PomBlock.new( :start )
        end

        should "has xml tag" do
            assert_equal :start, @pomblock.tag
        end

        should "support config" do
            @pomblock.config do
                sub "a"
            end

            assert_equal "a", @pomblock.configure.sub.__text__
        end

        should "support translating to node which config works as children" do
            @pomblock.config do
                sub "a"
            end

            node = TreeNode.new( :start ).__apply__(){ sub "a" }
            assert_equal @pomblock.to_treenode, node
        end
    end


    context "an artifact" do
        should "support tag, gid and aid" do
            at = Artifact.new( :r, :gid, :aid )
            at.config.execution

            assert_equal :r, at.tag
            assert_equal :gid, at.gid
            assert_equal :aid, at.aid
            assert_equal :execution, at.config.__children__[0].__tag__

            assert_equal at.to_treenode, (TreeNode.new( :r ).__apply__() do
                groupId :gid
                artifactId :aid
                execution
            end)
        end

        should "support version if nesseary" do
            at = Artifact.new( :r, :gid, :aid )
            at.version( "1.0" )

            assert_equal at.to_treenode, (TreeNode.new( :r ).__apply__() do
                groupId :gid
                artifactId :aid
                version "1.0"
            end)
            
        end
    end

    context "a pom" do
        setup do
            @pom = Pom.new( "info.thinkmore", "testpkg", "1.0.0" )
        end

        should "write xml with gid aid and version" do
            doc = XmlDoc.new(@pom)
            assert doc.elem( "/project/groupId" )
            assert_equal "info.thinkmore", doc.text( "/project/groupId" )
            assert_equal "testpkg", doc.text( "/project/artifactId" )
            assert_equal "1.0.0", doc.text( "/project/version" )
            assert_equal "4.0.0", doc.text( "/project/modelVersion" )
        end

        should "support plugins" do
            @pom.plugin( "gid:aid" ) do
                version( 100 )
            end

            doc = XmlDoc.new(@pom)

            assert_equal "gid", doc.text( "/project/build/plugins/plugin/groupId" )
            assert_equal "aid", doc.text( "/project/build/plugins/plugin/artifactId" )
            assert_equal "100", doc.text( "/project/build/plugins/plugin/version" )

            @pom.plugin( "gid1:aid1" ) 

            plugins = { "gid"=>"aid", "gid1"=>"aid1" }

            doc.elem( "/project/build/plugins/plugin" ) do |t|
                assert plugins.has_key? t.text( "groupId" )
                assert_equal plugins[ t.text("groupId") ], t.text( "artifactId" )
                plugins.delete t.text("groupId" )
            end
        end

        should " support plugin management" do
            @pom.plugin_mgr( "gid:aid" ) do
                version( 100 )
            end

            doc = XmlDoc.new(@pom)

            assert_equal "gid", doc.text( "/project/build/pluginManagement/plugins/plugin/groupId" )
            assert_equal "aid", doc.text( "/project/build/pluginManagement/plugins/plugin/artifactId" )
            assert_equal "100", doc.text( "/project/build/pluginManagement/plugins/plugin/version" )

            @pom.plugin_mgr( "gid1:aid1" ) 

            plugins = { "gid"=>"aid", "gid1"=>"aid1" }

            doc.elem( "/project/build/pluginManagement/plugins/plugin" ) do |t|
                assert plugins.has_key? t.text( "groupId" )
                assert_equal plugins[ t.text("groupId") ], t.text( "artifactId" )
                plugins.delete t.text("groupId" )
            end
        end


        should " support dependency" do
            @pom.dependency( "depg1:depa1" ) do
                version( "2.0" )
            end

            doc = XmlDoc.new(@pom)

            assert_equal "depg1", doc.text( "/project/dependencies/dependency/groupId" )
            assert_equal "depa1", doc.text( "/project/dependencies/dependency/artifactId" )
            assert_equal "2.0", doc.text( "/project/dependencies/dependency/version" )
        end

        should " treate artifact with same aid but different type as different dependencies" do
            @pom.dependency( "depg1:depa1" ) do
                version( "2.0" )
            end

            @pom.dependency( "depg1:depa1" ) do
                version( "2.0" )
                type "jar"
            end

            @pom.dependency( "depg1:depa1" ) do
                version( "2.0" )
                type "apk"
            end

            doc = XmlDoc.new(@pom)

            count = 0

            doc.elem("/project/dependencies/dependency") do |e|
                assert_equal "depg1", e.text( "groupId" )
                assert_equal "depa1", e.text( "artifactId" )
                assert_equal "2.0", e.text( "version" )

                count += 1 
            end

            assert 3, count
        end


        should " support dependency management" do
            @pom.dependency_mgr( "depg1:depa1" ) do
                version( "2.0" )
            end

            doc = XmlDoc.new(@pom)
            doc.dump

            assert_equal "depg1", doc.text( "/project/dependencyManagement/dependencies/dependency/groupId" )
            assert_equal "depa1", doc.text( "/project/dependencyManagement/dependencies/dependency/artifactId" )
            assert_equal "2.0", doc.text( "/project/dependencyManagement/dependencies/dependency/version" )
        end


        should " support modules" do
            fpom = Pom.new( :b, :c, "1.0" )

            @pom.mymodule( "abc", fpom )

            doc = XmlDoc.new(@pom)

            assert_equal "abc", doc.text( "/project/modules/module" )
        end

        should " support packaing" do
            @pom.packaging( :jar )
            doc = XmlDoc.new(@pom)
            assert_equal "jar", doc.text( "/project/packaging" )
        end

        should " support profile" do
            @pom.profile do
                plugin "a:b"
            end
            doc = XmlDoc.new(@pom)
            assert_equal "a", doc.text( "/project/profiles/profile/build/plugins/plugin/groupId" )
            assert_equal "b", doc.text( "/project/profiles/profile/build/plugins/plugin/artifactId" )
        end
    end
end
