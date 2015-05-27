require 'metaid'
require 'byebug'

module ThinWestLake
    class Node
        def initialize
            @prop = {}
        end

        def prop(prop_name)
            @prop[prop_name.to_sym]
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
                @prop[prop_sym ] = nc.new( *arg )
                if block2
                    @prop[prop_sym].instance_eval &block2
                end
            end
        end
    end

    class Project < Node
        attr_accessor :gid, :aid

        def initialize(gid, aid)
            super()
            @gid = gid.to_sym
            @aid = aid.to_sym
        end

        meta_eval do
            attr_accessor :root
        end
    end

    def self.project( gid, aid, &block )
        if Project.root
            raise ArgumentError.new("Only one project definition can exist!") 
        end

        Project.root = Project.new( gid, aid )
        if block
            Project.root.instance_eval &block
        end
    end

    def self.root
        Project.root
    end

    def self.reset
        Project.root = nil
    end
end
