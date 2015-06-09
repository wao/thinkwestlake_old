require 'simple_assert'
require 'byebug'
require 'rexml/document'
require 'builder'
require 'thinwestlake/helper'
require 'thinwestlake/maven/treenode'

module ThinWestLake
    module Maven
        class PomBlock
            include AttrRw

            def parse_id(mid)
                tm_assert{ mid.instance_of? String }
                ids = mid.split ':'
                tm_assert{ ids.length == 2 }
                ids.map { |id| id.to_sym }
            end

            attr_rw :tag, :xml_attrs

            def initialize( tag, xml_attrs = {} )
                @tag = tag
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
                tm_assert{ @tag }
                node = TreeNode.new( @tag, nil, @xml_attrs )
                node.__add_children__( @configure.__children__ )
                node
            end
        end

        class Artifact < PomBlock
            attr_reader :gid, :aid

            attr_rw :version, :xml_attrs, :tag

            def initialize( tag, gid, aid, version = nil, xml_attrs = {} )
                tm_assert{ tag && gid && aid }
                super( tag, xml_attrs )
                @gid = gid
                @aid = aid
                #puts "version=#{version}"
                if version == {}
                    byebug
                end
                @version = version
            end


            def to_treenode
                tm_assert{ @gid && @aid }
                node = super
                node.groupId( @gid )
                node.artifactId( @aid )
                #puts "version=#{@version}"
                if @version
                    node.version( @version )
                end
                node
            end

            #def children
                #@configure.__children__
            #end
        end


        class Dependency < Artifact
            attr_rw :scope
            attr_rw :type

            def initialize( gid, aid, version = nil )
                super( :dependency, gid, aid, version )
            end

            def to_treenode
                node = super
                node.scope @scope if @scope
                node.type @scope if @type
                node
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

        class Artifacts < PomBlock
            def initialize( tag, cls )
                super(tag)
                @cls = cls
                @artifacts = {}
            end

            def artifact( gid, aid, version=nil, options={}, &blk )
                @artifacts[ aid ] = @cls.new( gid, aid, version,&blk )
                if blk
                    @artifacts[ aid ].instance_eval &blk
                end
            end

            def empty?
                @artifacts.empty?
            end

            def to_treenode
                artifacts = super
                @artifacts.values.each do |artifact|
                    artifacts.__add_child__( artifact.to_treenode )
                end
                artifacts
            end
        end

        class PomBlocks < PomBlock
            def initialize( tag, cls )
                super(tag)
                @cls = cls
                @blocks = []
            end

            def pom_block( *arg, &blk )
                block = @cls.new(*arg)
                @blocks << block
                if blk
                    block.instance_eval &blk
                end
            end

            def empty?
                @blocks.empty?
            end

            def to_treenode
                root_node = super
                @blocks.each do |block|
                    root_node.__add_child__( block.to_treenode )
                end
                root_node
            end
        end

        class Dependencies < Artifacts
            def initialize
                super( :dependencies, Dependency )
            end

            alias_method :dependency, :artifact
        end

        module DepenciesBlock
            def dependency( id, version=nil, options={}, &blk )
                ids = parse_id(id)
                @dependencies.dependency( ids[0], ids[1], version, options, &blk )
            end

            def dependencies_block_init
                @dependencies = Dependencies.new
            end


            def dependencies_block_to_treenode(root_node)
                root_node.__add_child__( @dependencies.to_treenode ) unless @dependencies.empty? 
                root_node
            end
        end

        class Plugin < Artifact
            include DepenciesBlock
            def initialize( gid, aid, version =nil )
                super( :plugin, gid, aid, version )
                dependencies_block_init
            end

            def configuration(&blk)
                config do
                    configuration do
                        instance_eval &blk
                    end
                end
            end

            def to_treenode
                root_node = super
                dependencies_block_to_treenode(root_node)
                root_node
            end
        end


        class Plugins < Artifacts
            def initialize
                super( :plugins, Plugin )
            end

            alias_method :plugin, :artifact
        end

        module BuildBlock
            include DepenciesBlock

            def build_block_init
                dependencies_block_init
                @plugins = Plugins.new
                @plugin_management = Plugins.new
                @dependency_management = Dependencies.new
                @modules = {}
            end

            def build_block_to_treenode(root_node)
                dependencies_block_to_treenode(root_node)
                root_node.dependencyManagement.__add_child__( @dependency_management.to_treenode ) unless @dependency_management.empty?
                #TODO same method should return same node
                root_node.build.__add_child__( @plugins.to_treenode ) unless @plugins.empty?
                root_node.build.pluginManagement.__add_child__( @plugin_management.to_treenode ) unless @plugin_management.empty?
                root_node
            end

            def plugin( id, version=nil, options={}, &blk )
                ids = parse_id(id)
                @plugins.plugin( ids[0], ids[1], version, options, &blk )
            end

            def plugin_mgr( id, options={}, version=nil, &blk )
                ids = parse_id(id)
                @plugin_management.plugin( ids[0], ids[1],version, options, &blk )
            end

            def dependency_mgr( id, version=nil, options={}, &blk )
                ids = parse_id(id)
                @dependency_management.dependency( ids[0], ids[1], version, options, &blk )
            end
        end

        class Profile < PomBlock
            include BuildBlock

            def initialize
                super( :profile )
                build_block_init
            end

            def to_treenode
                build_block_to_treenode( super )
            end
        end

        class Profiles < PomBlocks
            def initialize
                super( :profiles, Profile )
            end

            alias_method :profile, :pom_block
        end


        class Pom < Artifact
            include BuildBlock

            POM_DECL = { 'xmlns'=>"http://maven.apache.org/POM/4.0.0",'xmlns:xsi'=>"http://www.w3.org/2001/XMLSchema-instance",'xsi:schemaLocation'=>"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd" }

            attr_rw :packaging, :parent, :name

            def initialize( gid, aid, version, &blk )
                tm_assert{ gid && aid && version }
                super( :project, gid, aid, version, POM_DECL )
                build_block_init
                @profiles = Profiles.new

                if blk
                    instance_eval &blk
                end
            end

            def mymodule( path, pom )
                @modules[ path ] = pom
            end

            def mymodules
                @modules
            end

            def profile( &blk )
                @profiles.profile( &blk )
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

                root_node.packaging @packaging if @packaging
                root_node.name @name if @name

                if !@modules.empty?
                    modules = root_node.modules
                    @modules.keys.each do |mod|
                        modules.module( mod )
                    end
                end

                build_block_to_treenode(root_node)
                root_node.__add_child__( @profiles.to_treenode ) if !@profiles.empty?

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
