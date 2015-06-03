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
            attr_reader :gid, :aid

            def self.attr_rw( *args )
                args.each do |arg|
                    def_accessor( arg )
                end
            end

            def self.def_accessor( attr_name )
                self.class_eval "
                    def #{attr_name}(value=nil) 
                        if value.nil?
                            @#{attr_name}
                        else
                            @#{attr_name} = value
                            self
                        end
                    end"
            end

            attr_rw :version, :xml_attrs, :tag

            def initialize( tag, gid, aid, version = nil, xml_attrs = {} )
                tm_assert{ tag && gid && aid }
                @tag = tag
                @gid = gid
                @aid = aid
                @version = version
                @xml_attrs = xml_attrs
                @configure = TreeNode.new( @tag )
            end

            def config( &blk )
                if blk
                    @configure.instance_eval &blk 
                end
                @configure
            end

            def to_treenode
                tm_assert{ @tag && @gid && @aid }
                node = TreeNode.new( @tag, nil, @xml_attrs )
                node.groupId( @gid )
                node.artifactId( @aid )
                if @version
                    node.version( @version )
                end
                node.children.concat children
                node
            end

            def children
                @configure.children
            end
        end

        class Plugin < Artifact
            def initialize( gid, aid )
                super( :plugin, gid, aid )
            end
        end

        class Dependency < Artifact
            def initialize( gid, aid )
                super( :dependency, gid, aid )
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

        class Artifacts
            def initialize( tag, cls )
                @tag = tag
                @cls = cls
                @artifacts = {}
            end

            def artifact( gid, aid, options={}, &blk )
                @artifacts[ aid ] = @cls.new( gid, aid, &blk )
                if blk
                    @artifacts[ aid ].config &blk
                end
            end

            def empty?
                @artifacts.empty?
            end

            def to_treenode
                artifacts = TreeNode.new( @tag )
                @artifacts.values.each do |artifact|
                    artifacts.children << artifact.to_treenode
                end
                artifacts
            end
        end


        class Plugins < Artifacts
            def initialize
                super( :plugins, Plugin )
            end

            alias_method :plugin, :artifact
        end

        class Dependencies < Artifacts
            def initialize
                super( :dependencies, Dependency )
            end

            alias_method :dependency, :artifact
        end

        class Pom < Artifact
            POM_DECL = { 'xmlns'=>"http://maven.apache.org/POM/4.0.0",'xmlns:xsi'=>"http://www.w3.org/2001/XMLSchema-instance",'xsi:schemaLocation'=>"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd" }

            attr_rw :packaging, :parent, :name
            attr_reader :modules

            def initialize( gid, aid, version, &blk )
                tm_assert{ gid && aid && version }
                super( :project, gid, aid, version, POM_DECL )
                @plugins = Plugins.new
                @dependencies = Dependencies.new
                @plugin_management = Plugins.new
                @dependency_management = Dependencies.new
                @modules = {}

                if blk
                    instance_eval &blk
                end
            end

            def module( path, pom )
                @modules[ path ] = pom
            end

            def parse_id(mid)
                tm_assert{ mid.instance_of? String }
                ids = mid.split ':'
                tm_assert{ ids.length == 2 }
                ids.map { |id| id.to_sym }
            end

            def plugin( id, options={}, &blk )
                ids = parse_id(id)
                @plugins.plugin( ids[0], ids[1], options, &blk )
            end

            def dependency( id, options={}, &blk )
                ids = parse_id(id)
                @dependencies.dependency( ids[0], ids[1], options, &blk )
            end

            def plugin_mgr( id, options={}, &blk )
                ids = parse_id(id)
                @plugin_management.plugin( ids[0], ids[1], options, &blk )
            end

            def dependency_mgr( id, options={}, &blk )
                ids = parse_id(id)
                @dependency_management.dependency( ids[0], ids[1], options, &blk )
            end


            def root
                root_node = to_treenode
                root_node.modelVersion( '4.0.0' )

                if @parent
                    parent_pom = @parent
                    root_node.parent do
                        groupId parent_pom.gid
                        artifactId parent_pom.aid
                        version parent_pom.version
                    end
                end

                root_node.packaging @packaging
                root_node.name @name

                if !@modules.empty?
                    modules = root_node.modules
                    @modules.keys.each do |mod|
                        modules.module( mod )
                    end
                end

                root_node.children << @dependencies.to_treenode unless @dependencies.empty?
                root_node.dependencyManagement.children << @dependency_management.to_treenode unless @dependency_management.empty?
                #TODO same method should return same node
                root_node.build.children << @plugins.to_treenode unless @plugins.empty?
                root_node.build.pluginManagement.children << @plugin_management.to_treenode unless @plugin_management.empty?
                root_node
            end

            def to_xml(builder=nil)
                builder ||= Builder::XmlMarkup.new(:indent=>2)
                builder.instruct!
                root.to_xml(builder)
                builder
            end
        end
    end
end
