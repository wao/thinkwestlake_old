require 'metaid'
require 'byebug'
require 'simple_assert'
require 'thinwestlake/maven/pom'
require 'thinwestlake/helper'

module ThinWestLake
    class Node
        include AttrRw

        def initialize
            @prop = {}
            @node = {}
            @pom = {}
        end

        def prop(prop_name)
            @prop[prop_name.to_sym]
        end

        def node(node_name)
            @node[node_name.to_sym]
        end

        def self.boolean( prop_name )
            prop_sym = prop_name.to_sym
            define_method prop_sym do
                @prop[prop_sym] = true
            end

            define_method "no_#{prop_sym}".to_sym do
                @prop[prop_sym] = false
            end
        end

        def self.enum( prop_name, value_list )
            prop_sym = prop_name.to_sym
            define_method prop_sym do |value|
                raise ArgumentError.new( "#Wrong value #{value} for {prop_name}" ) if !value_list.include? value
                @prop[prop_sym] = value
            end
        end

        def self.node( prop_name, node_class = Node, &block )
            prop_sym = prop_name.to_sym
            nc = node_class
            if block
                nc = Class.new(node_class)
                nc.class_eval &block
            end

            define_method prop_sym, ->(*arg, &block2) do 
                @node[prop_sym ] = nc.new( *arg )
                if block2
                    @node[prop_sym].instance_eval &block2
                end
            end
        end

        def configure(project=nil)
            @pom.each_pair do |pom_name, blk|
                tm_assert{ blk }

                target_pom = project.pom(pom_name)
                raise "Unknown pom #{pom_name}" if target_pom.nil?

                target_pom.instance_eval &blk
            end
        end

        def pom(name, &blk)
            @pom[name.to_sym] = blk
        end
    end

    class SimpleFileMgr
        def mkdir( path )
            FileUtils.mkdir_p path
        end

        def write_file( filename, &blk ) 
            File.open( filename, "w", &blk )
        end
    end

    class DumpFileMgr
        def mkdir( path )
            puts "mkdir #{path}"
        end

        def write_file( filename, &blk )
            puts "write to file #{filename}"
            a = ""
            blk.call(a)
            puts a
        end
    end

    class Project < Node
        attr_rw :gid, :aid, :version, :java_package

        def pom( name = nil, value = nil )
            if name.nil?
                name = :default
            else
                name = name.to_sym
            end


            if value.nil?
                @pom[name]
            else
                tm_assert{ value.is_a? Maven::Pom }
                @pom[name] = value
                self
            end
        end

        def initialize(gid, aid, version)
            tm_assert{ gid && aid }
            super()
            @gid = gid.to_sym
            @aid = aid.to_sym
            @version = version
            @pom = {}
            self.class.last_instance=self
        end

        meta_eval do
            attr_accessor :last_instance
        end

        def configure( root_prj = nil )
            tm_assert{ root_prj.nil? }
            tm_assert{ @version }
            pom( :root, Maven::Pom.new( @gid, @aid, @version ) )
            pom( :default,  pom(:root) )

            @node.each_value do |v|
                v.configure( self )
            end

            #if !@subtwl.empty? 
                #if pom( :root ).packaging.nil? || ( pom( :root ).packaging.to_sym == :pom )
                    ##TODO add module of package
                #else
                    #raise "Need to add module but packaging is not pom"
                #end
            #end
        end

        def create_pom( file_mgr, pom, path = nil )
            filename = "pom.xml"
            if path
                file_mgr.mkdir( path.to_s )
                filename = path.to_s + "/pom.xml"
            end
        
            file_mgr.write_file( filename ) do |wr|
                builder = Builder::XmlMarkup.new(:target=>wr, :indent=>2)
                pom.to_xml(builder)
            end
        end

        def generate(file_mgr=nil)
            file_mgr ||= SimpleFileMgr.new
            create_pom( file_mgr, pom(:root) )
            pom(:root).mymodules.each_pair do |p,v|
                create_pom( file_mgr, v, p )
            end
        end
    end

    def self.project( gid, aid, version=nil, &block )
        #if Project.root
            #raise ArgumentError.new("Only one project definition can exist!") 
        #end

        root = Project.new( gid, aid, version )
        if block
            root.instance_eval &block
        end
        root
    end

    def self.extension( &blk )
        Project.class_eval &blk
    end
end
