require 'simple_assert'
require 'byebug'
require 'rexml/document'
require 'builder'

module ThinWestLake
    module Maven
        class TreeNode
            attr_reader :tag, :children, :attrs, :text

            def initialize(tag, text = nil, attrs={})
                @tag = tag.to_sym
                @attrs = attrs
                @text = text
                @children = []
            end

            def method_missing( method_sym, *args, &blk )
                (tag, attrs) = args
                child = TreeNode.new(method_sym, tag, attrs)
                @children << child
                if blk
                    child.instance_eval &blk
                end

                child
            end

            def to_xml(builder)
                tm_assert( "A element #{@tag} can't have text and children element at same type" ) { @text.nil? || @children.empty? }
                if @text.nil?
                    builder.__send__( @tag, nil, @attrs ) do
                        @children.each{ |child| child.to_xml( builder ) }
                    end
                else
                    builder.__send__( @tag, @text.to_s, @attrs )
                end
            end
        end

        class Artifact 
            attr_reader :gid, :aid, :node
            attr_accessor :version, :xml_attrs

            def initialize( tag, gid, aid, xml_attrs = {},  &blk )
                tm_assert{ tag && gid && aid }
                @tag = tag
                @gid = gid
                @aid = aid
                @node = TreeNode.new( @tag )
                @node.groupId( gid )
                @node.artifactId( aid )
                @xml_attrs = xml_attrs

                if blk
                    @node.instance_eval &blk
                end
            end

            def to_treenode
                tm_assert{ @tag && @gid && @aid }
                node = TreeNode.new( @tag, nil, @xml_attrs )
                node.groupId( @gid )
                node.artifactId( @aid )
                if @version
                    node.version( @version )
                end
                node
            end
        end

        class Plugin < Artifact
            def initialize( gid, aid, &blk )
                super( :plugin, gid, aid, &blk )
            end
        end

        class Dependency < Artifact
            def initialize( gid, aid, &blk )
                super( :dependency, gid, aid, &blk )
            end
        end

        class ArtifactRepo
            MAP = {}

            def self.add( gid, aid, &blk )
                artifact = Artifact.new(gid, aid)
                artifact.instance_eval &blk
                MAP[aid] = artifact
            end

        end

        class Pom < Artifact
            POM_DECL = { 'xmlns'=>"http://maven.apache.org/POM/4.0.0",'xmlns:xsi'=>"http://www.w3.org/2001/XMLSchema-instance",'xsi:schemaLocation'=>"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd" }
            attr_accessor :package

            def initialize( gid, aid, version )
                tm_assert{ gid && aid && version }
                super( :project, gid, aid, POM_DECL )
                self.version = version
                @plugins = {}
                @dependencies = {}
            end

            def parse_id(mid)
                tm_assert{ mid.instance_of? String }
                ids = mid.split ':'
                tm_assert{ ids.length == 2 }
                ids.map { |id| id.to_sym }
            end

            def plugin( id, options={}, &blk )
                ids = parse_id( id )
                @plugins[ ids[1] ] = Plugin.new( ids[0], ids[1], &blk )
            end

            def dependency( *args )
                args.each do |elem|
                    raise ArgumentError.new( "Plugin #{elem} is not exists in repo" ) if ArtifactRepo::MAP.include?( elem )
                end

                @dependencies.concat args
            end

            def root
                root_node = to_treenode
                root_node.modelVersion( '4.0.0' )
                plugins = root_node.plugins
                @plugins.values.each do |plugin|
                    plugins.children << plugin.to_treenode
                end
                root_node
            end

            def to_xml
                builder = Builder::XmlMarkup.new(:indent=>2)
                root.to_xml(builder)
                builder
            end
        end
    end
end
