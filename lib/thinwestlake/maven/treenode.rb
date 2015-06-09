require 'simple_assert'
require 'byebug'

module ThinWestLake
    module Maven
        class BlankSlate < Module
            class << self

                # Hide the method named +name+ in the BlankSlate class.  Don't
                # hide +instance_eval+ or any method beginning with "__".
                def hide(name)
                    warn_level = $VERBOSE
                    $VERBOSE = nil
                    if instance_methods.include?(name.to_sym) &&
                        name !~ /^(__|instance_eval|tm_assert|equal\?|nil\?|!|is_a\?|byebug|throw|class|inspect|instance_variable_set|object_id|instance_variable_get|to_s|method$)/
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

            alias_method :__methods__, :methods

            instance_methods.each { |m| hide(m.to_s) }
        end

        module AsList
            def __match_item_with_opt__( item, opts )
                opts.each_pair do |n,v|
                    node = item.__get_node__( n.to_sym ) 
                    if node.nil? or ( node.__text__ != v )
                        return false
                    end
                end
                true
            end

            def __item__( filter_opts = {}, &blk )
                tm_assert{ __list? }
                ret = @children.find do |item|
                    __match_item_with_opt__( item, filter_opts )
                end

                if ret.nil?
                    ret = TreeNode.new( @subtag )
                    filter_opts.each_pair do |n,v|
                        puts "#{n}====#{v}"
                        #byebug
                        ret.__send__(n,v)
                    end
                    @children << ret
                end

                if blk
                    ret.instance_eval &blk
                end

                ret
            end
        end

        class TreeNode < BlankSlate
            include AsList

            @name_map = {}

            def self.map_name( method_name, tag_name )
                @name_map[method_name.to_sym ] = tag_name.to_sym
            end

            def self.lookup_name( method_name )
                ret =  @name_map[ method_name.to_sym ]
                if ret.nil?
                    method_name.to_sym
                else
                    ret
                end
            end


            map_name( :mymodule, "module" )

            def initialize(tag, text = nil, attrs={})
                @tag = self.class.lookup_name(tag.to_sym)
                @attrs = attrs
                @text = text
                @children = []
                @state = :unknown
                if text
                    @state = :node
                end
            end

            def __get_node__(node_name)
                instance_variable_get( :"@#{node_name}" )
            end

            def __meta_id__
                class << self
                    self
                end
            end

            def __list?
                @state == :list
            end

            def __tag__
                @tag
            end

            def __attrs__
                @attrs
            end

            def __text__(value=nil)
                tm_assert{ !__list? }
                if @statue == :unknown
                    @statue = :node
                end

                if value.nil?
                    @text
                else
                    @text = value
                end
            end

            REGEXP_ALPHA_START = /^[a-z][A-Za-z0-9.]+$/

            def [](selector={},&blk)
                case @state
                when :unknown
                    @state = :list
                    @subtag = @tag
                    @tag = (@tag.to_s + "s").to_sym
                when :node
                    raise "Node #{@tag} already act as node, can't be treated as list"
                end

                __item__( selector, &blk ) 
            end

            def method_missing( method_sym, *args, &blk )
                puts method_sym
                if __list?
                    super
                else
                    (text, attrs) = args
                    #byebug
                    __new_node__( method_sym, text, attrs, &blk )
                end
            end

            def __new_node__(tag, text=nil, attrs=nil,&blk)
                if @state == :unknown
                    @state = :node
                end

                tm_assert{ !__list? }

                if !tag.to_s.match( REGEXP_ALPHA_START )
                    throw ArgumentError.new( "#{tag} is not a valid xml tag" )
                end
                child = TreeNode.new( tag, text, attrs)

                instance_variable_set( ("@" + tag.to_s).to_sym, child )

                __meta_id__.class_eval "
                        def #{child.__tag__}(&blk)
                            ret = @#{child.__tag__} 
                            if blk
                               ret.instance_eval &blk
                            end
                            ret
                        end"

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
    end
end
