require_relative "../../test_helper"

require 'thinwestlake/maven/pom'

include ThinWestLake::Maven

class TestMavenPom < Minitest::Test
    context "Simple TreeNode" do
        setup do
            @root = TreeNode.new(:root)
        end

        should "has tag root" do
            assert_equal :root, @root.tag
        end

        should "create a child with method" do
            c = @root.xml
            assert_same c, @root.children[0]
            assert_equal :xml, c.tag
        end


        should "be able to create a 2-level child in block" do
            @root.xml {
                fake
            }

            assert_equal :fake, @root.children[0].children[0].tag
        end
    end

    context "a TreeNode with attributes" do
        setup do
            @root = TreeNode.new(:root, nil, :class=>"kk")
        end

        should "has a attribute name is :class, value is kk" do
            assert_equal "kk", @root.attrs[:class]
        end

        should "be able to create a children with attrs" do
            @root.xml( nil, :cfg=>"none" )
            assert_equal "none", @root.children[0].attrs[:cfg]
        end
    end

    context "a article" do
        should "add tag, gid and aid" do
            at = Artifact.new( :r, :gid, :aid ) do
                execution
            end

            assert_equal :r, at.node.tag
            assert_equal :gid, at.gid
            assert_equal :gid, at.node.children[0].text
            assert_equal :aid, at.aid
            assert_equal :aid, at.node.children[1].text
            assert_equal :execution, at.node.children[2].tag
        end
    end
end
