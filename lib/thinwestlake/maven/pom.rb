require 'simple_assert'
require 'byebug'
require 'rexml/document'
require 'builder'
require 'thinwestlake/helper'
require 'thinwestlake/maven/treenode'

module ThinWestLake
    module Maven
        # Repesent a xml block with tag. 
        class PomBlock
            include AttrRw

            # Parse a "gid:aid" string to a two element array contains [gid, aid]
            #
            # @param mid [String] id string like "gid:aid"
            # @return [Array] of 2 elements [gid,aid]
            def parse_id(mid)
                tm_assert{ mid.is_a? String }
                ids = mid.split ':'
                tm_assert{ ids.length == 2 }
                ids.map { |id| id.to_sym }
            end

            attr_rw :tag, :xml_attrs, :configure

            def initialize( tag, xml_attrs = {} )
                tm_assert{ tag.is_a? Symbol }
                @tag = tag
                @xml_attrs = xml_attrs
                @configure = TreeNode.new( @tag )
            end

            # Allow user using code block to construct inner xml structure
            def config( &blk )
                if blk
                    @configure.instance_eval &blk 
                end
                @configure
            end

            # Translate to a tree node representatin which can easily produce xml file.
            def to_treenode
                tm_assert{ @tag }
                node = TreeNode.new( @tag, nil, @xml_attrs )
                node.__add_children__( @configure.__children__ )
                node
            end
        end

        # A xml block specify gid, aid and version, denote an artifact of pom
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
        end


        # A dependency of pom
        class Dependency < Artifact
            attr_rw :scope
            attr_rw :type

            def initialize( gid, aid, version = nil )
                super( :dependency, gid, aid, version )
            end

            def to_treenode
                node = super
                node.scope @scope if @scope
                node.type @type if @type
                node
            end
        end

        # A list of artifacts
        class Artifacts < PomBlock
            def initialize( tag, cls )
                super(tag)
                @cls = cls
                @artifacts = {}
            end

            # Add an artifact
            def artifact( gid, aid, version=nil, options={}, &blk )
                obj = @cls.new( gid, aid, version,&blk )
                if blk
                    obj.instance_eval &blk
                end
                @artifacts[ gen_key(obj)] = obj
            end

            def gen_key(obj)
                obj.aid
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

        # A list of xml blocks which have same tag
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

        # A list of depencies
        class Dependencies < Artifacts
            def initialize
                super( :dependencies, Dependency )
            end

            def gen_key(obj)
                #byebug
                #puts "#{obj.aid}:#{obj.type}"
                "#{obj.aid}:#{obj.type}"
            end

            def get_obj_type(obj)
                if obj.config.__has_node__?(:type)
                    obj.config.type.__text__
                else
                    nil
                end
            end

            alias_method :dependency, :artifact
        end

        # Mixin for support depencies
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

        # A plugin in
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


        # A list of plugin
        class Plugins < Artifacts
            def initialize
                super( :plugins, Plugin )
            end

            alias_method :plugin, :artifact
        end

        # Mixin to support plugins, pluginmanagement and dependency management
        module BuildBlock
            include DepenciesBlock

            def build_block_init
                dependencies_block_init
                @plugins = Plugins.new
                @plugin_management = Plugins.new
                @dependency_management = Dependencies.new
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

        # Profile 
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

        # Profiles
        class Profiles < PomBlocks
            def initialize
                super( :profiles, Profile )
            end

            alias_method :profile, :pom_block
        end


        # A pom
        class Pom < Artifact
            include BuildBlock

            POM_DECL = { 'xmlns'=>"http://maven.apache.org/POM/4.0.0",'xmlns:xsi'=>"http://www.w3.org/2001/XMLSchema-instance",'xsi:schemaLocation'=>"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd" }

            attr_rw :packaging, :parent, :name

            def initialize( gid, aid, version, &blk )
                tm_assert{ gid && aid && version }
                super( :project, gid, aid, version, POM_DECL )
                build_block_init
                @profiles = Profiles.new
                @modules = {}

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
                        modules.mymodule( mod )
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
