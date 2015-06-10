require_relative "../../../test_helper"

require 'thinwestlake/maven/pom'

include ThinWestLake::Maven

class TestMavenPom < Minitest::Test
    context "a PomBlock" do
        setup do 
            @pomblock = PomBlock.new( :start )
        end

        should "has xml tag" do
            assert_equal :start, @pomblock.tag
        end

        should "allow config" do
            @pomblock.config do
                sub "a"
            end

            assert_equal "a", @pomblock.configuration.sub.__text__
        end

        should "can translate to node which config works as children" do
            @pomblock.config do
                sub "a"
            end

            assert_equal @pomblock.to_treenode, TreeNode.new( :start ) do
                sub "a"
            end
        end
    end



    context "a article" do
        should "add tag, gid and aid" do
            at = Artifact.new( :r, :gid, :aid )
            at.config.execution

            assert_equal :r, at.tag
            assert_equal :gid, at.gid
            assert_equal :aid, at.aid
            assert_equal :execution, at.config.__children__[0].__tag__
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
                version = 100 
            end

            puts @pom.to_xml.target!
        end
    end
end
