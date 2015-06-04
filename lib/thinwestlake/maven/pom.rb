require 'simple_assert'
require 'byebug'
require 'rexml/document'
require 'builder'

module ThinWestLake
    module Maven
        class BlankSlate
            class << self

                # Hide the method named +name+ in the BlankSlate class.  Don't
                # hide +instance_eval+ or any method beginning with "__".
                def hide(name)
                    warn_level = $VERBOSE
                    $VERBOSE = nil
                    if instance_methods.include?(name.to_sym) &&
                        name !~ /^(__|instance_eval|tm_assert|equal\?|nil\?|!|is_a\?$)/
                        @hidden_methods ||= {}
                        @hidden_methods[name.to_sym] = instance_method(name)
                        undef_method name
                    end
                ensure
                    $VERBOSE = warn_level
                end

                def find_hidden_method(name)
                    @hidden_methods ||= {}
                    @hidden_methods[name] || superclass.find_hidden_method(name)
                end

                # Redefine a previously hidden method so that it may be called on a blank
                # slate object.
                def reveal(name)
                    hidden_method = find_hidden_method(name)
                    fail "Don't know how to reveal method '#{name}'" unless hidden_method
                    define_method(name, hidden_method)
                end
            end

            instance_methods.each { |m| hide(m.to_s) }
        end

        class TreeNode < BlankSlate
            def initialize(tag, text = nil, attrs={})
                @tag = tag.to_sym
                @attrs = attrs
                @text = text
                @children = []
            end

            def __tag__
                @tag
            end

            def __attrs__
                @attrs
            end

            def __text__
                @text
            end

            REGEXP_ALPHA_START = /^[A-Za-z0-9]+$/

            def method_missing( method_sym, *args, &blk )
                (tag, attrs) = args
                if !method_sym.to_s.match( REGEXP_ALPHA_START )
                    throw ArgumentError.new( "#{method_sym} is not a valid xml tag" )
                end
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
                        @children.each{ |child| 
                            byebug if child.nil?
                            child.to_xml( builder ) 
                        }
                    end
                else
                    #puts "#{tag}:#{@text.to_s}:#{@attrs}"
                    builder.__send__( @tag, @text.to_s, @attrs )
                end
            end

            def __add_child__(child)
                if child.nil?
                    byebug
                end
                tm_assert{ child }
                tm_assert{ child.is_a? TreeNode }
                @children << child
                self
            end

            def __add_children__(children)
                tm_assert{ children.none? { |v| v.nil? } }
                tm_assert{ children.all? { |v| v.is_a? TreeNode } }
                @children.concat children
            end

            def __children__
                @children
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

            def parse_id(mid)
                tm_assert{ mid.instance_of? String }
                ids = mid.split ':'
                tm_assert{ ids.length == 2 }
                ids.map { |id| id.to_sym }
            end


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
                node.__add_children__( @configure.__children__ )
                node
            end

            #def children
                #@configure.__children__
            #end
        end


        class Dependency < Artifact
            attr_rw :scope
            attr_rw :type

            def initialize( gid, aid )
                super( :dependency, gid, aid )
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

        class Artifacts
            def initialize( tag, cls )
                @tag = tag
                @cls = cls
                @artifacts = {}
            end

            def artifact( gid, aid, options={}, &blk )
                @artifacts[ aid ] = @cls.new( gid, aid, &blk )
                if blk
                    @artifacts[ aid ].instance_eval &blk
                end
            end

            def empty?
                @artifacts.empty?
            end

            def to_treenode
                artifacts = TreeNode.new( @tag )
                @artifacts.values.each do |artifact|
                    artifacts.__add_child__( artifact.to_treenode )
                end
                artifacts
            end
        end

        class Dependencies < Artifacts
            def initialize
                super( :dependencies, Dependency )
            end

            alias_method :dependency, :artifact
        end

        module DepenciesBlock
            def dependency( id, options={}, &blk )
                ids = parse_id(id)
                @dependencies.dependency( ids[0], ids[1], options, &blk )
            end

            def dependencies_block_init
                @dependencies = Dependencies.new
            end


            def dependencies_block_to_treenode(root_node)
                root_node.__add_child__( @dependencies.to_treenode ) unless @dependencies.empty? 
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
            end

            def plugin( id, options={}, &blk )
                ids = parse_id(id)
                @plugins.plugin( ids[0], ids[1], options, &blk )
            end

            def plugin_mgr( id, options={}, &blk )
                ids = parse_id(id)
                @plugin_management.plugin( ids[0], ids[1], options, &blk )
            end

            def dependency_mgr( id, options={}, &blk )
                ids = parse_id(id)
                @dependency_management.dependency( ids[0], ids[1], options, &blk )
            end
        end


        class Pom < Artifact
            include BuildBlock

            POM_DECL = { 'xmlns'=>"http://maven.apache.org/POM/4.0.0",'xmlns:xsi'=>"http://www.w3.org/2001/XMLSchema-instance",'xsi:schemaLocation'=>"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd" }

            attr_rw :packaging, :parent, :name
            attr_reader :modules

            def initialize( gid, aid, version, &blk )
                tm_assert{ gid && aid && version }
                super( :project, gid, aid, version, POM_DECL )
                build_block_init

                if blk
                    instance_eval &blk
                end
            end

            def module( path, pom )
                @modules[ path ] = pom
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
