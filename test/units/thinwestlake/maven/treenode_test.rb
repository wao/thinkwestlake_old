require_relative '../../../test_helper.rb'

require 'thinwestlake/maven/treenode.rb'

include ThinWestLake::Maven

class TestProject < Minitest::Test
    context "a treenode which is created with tag :root" do
        setup do
            @root = TreeNode.new(:root)
        end

        should "can query tag with __tag__" do
            assert_equal :root, @root.__tag__
        end

        should "can create a child with method" do
            assert !@root.__methods__.include?(:xml)
            c = @root.xml
            assert_same c, @root.xml
            assert_same c, @root.__children__[0]
            assert_equal :xml, c.__tag__
        end

        should "be able to create a 2-level child in block" do
            @root.xml {
                fake
            }

            assert_equal :fake, @root.__children__[0].__children__[0].__tag__
            assert_nil @root.xml.fake.__text__

            @root.xml.fake do
                __text__ "hello"
            end

            assert_equal "hello", @root.xml.fake.__text__
        end

        should "change to list if operation [] is used" do
            a = @root.plugin.as_list(:id=>"run")
            assert_equal :plugins, @root.__children__[0].__tag__, "tag will become plurs"
            assert_same a, @root.__children__[0].__children__[0], "a sub item will be create if is not exist"
            assert_equal :plugin, a.__tag__
            assert_equal :id, a.id.__tag__
            assert_equal "run", a.id.__text__
            assert_same  a, @root.plugin.as_list( :id=>"run" )
        end
    end

    context "a treenode which is created as node " do
        setup do
            @root = TreeNode.new(:root)
            @root.plugin( "good" )
        end

        should "not change to list" do
            assert_raises RuntimeError do
                @root.plugin.as_list( :id=>"a" )
            end
        end
    end

    context "a treenode which is created as array " do
        setup do
            @root = TreeNode.new(:root)
            @root.plugin.as_list
        end

        should " not has __text__" do
            assert_raises RuntimeError do
                @root.plugin do
                    __text__ "good"
                end
            end
        end
    end

    context "a treenode which is created as array " do
        setup do
            @root = TreeNode.new(:root)
        end

        should " define operator [] to return self" do
            @root.plugin.as_list( :v=>"c" )
            assert_same @root.plugin.as_list, @root.__children__[0]
        end

        should " have method to add new children" do
            @root.plugin.as_list { 
                plugin "abc"
            }

            assert_equal "abc", @root.plugin.as_list.__children__[0].__text__
        end
    end
end
