require 'simple_assert'
require 'byebug'
require 'set'

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
                        name !~ /^(__|instance_eval|tm_assert|equal\?|nil\?|!|is_a\?|byebug|throw|class|inspect|instance_variable_set|object_id|instance_variable_get|to_s|method|instance_of\?|respond_to\?|to_ary|hash|eql\?$)/
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
            map_name( :mytest, "test" )

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

            def __apply__(&blk)
                tm_assert{ blk }
                instance_eval &blk
                self
            end

            def != (value)
                !(self == value)
            end

            def to_s
                "#{@tag}:#{@state}:#{@text}[#{@children.map{ |c| c.to_s }.join('|')}]"
            end

            
            def to_str
                to_s
            end

            def inspect
                "[#{self.class}]#{object_id}:#{to_s}"
            end

            #def hash
                #ret = @tag.hash ^ @text.hash
                #if @attrs.nil?
                    #ret = ret ^ @attrs.hash
                #else
                    #@attrs.each_pair do |n,v|
                        #ret = ret ^ n.hash ^ v.hash
                    #end
                #end

                #@children.each do |c|
                    #ret = ret ^ c.hash
                #end

                #ret
            #end


            def == (value)
                if value.is_a? TreeNode
                    ret = [ :@tag, :@attrs, :@text ].all? do |sym|
                        instance_variable_get(sym) == value.instance_variable_get(sym)
                    end
                    if ret
                        children = value.instance_variable_get(:@children)
                        if children.size == @children.size
                            children.all? do |c|
                                @children.include? c
                            end
                        else
                            false
                        end
                    else
                        false
                    end
                else
                    false
                end
            end

            def __has_node__?(node_name)
                !__get_node__(node_name).nil?
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

            REGEXP_ALPHA_START = /^[a-z][A-Za-z0-9.]*$/

            def __change_to_list__
                @state = :list
                @subtag = @tag
                @tag = (@tag.to_s + "s").to_sym

                __meta_id__.class_eval "
                        def #{@subtag}(text=nil, attrs=nil,&blk)
                            ret = TreeNode.new( :#{@subtag}, text, attrs )
                            @children << ret
                            if blk
                               ret.instance_eval &blk
                            end
                            ret
                        end"
            end

            def as_list(selector=nil,&blk)
                case @state
                when :unknown
                    __change_to_list__
                when :node
                    raise "Node #{@tag} already act as node, can't be treated as list"
                end

                if selector.nil?
                    if blk
                        instance_eval &blk
                    end

                    self
                else
                    __item__( selector, &blk ) 
                end
            end

            def method_missing( method_sym, *args, &blk )
                #puts method_sym
                if __list?
                    super
                else
                    (text, attrs) = args
                    #byebug
                    __new_node__( method_sym, text, attrs, true, &blk )
                end
            end

            def __new_node__(tag, text=nil, attrs=nil, reader=false, &blk)
                if @state == :unknown
                    @state = :node
                end

                tm_assert{ !__list? }

                if !tag.to_s.match( REGEXP_ALPHA_START )
                    throw ArgumentError.new( "#{tag} is not a valid xml tag" )
                end
                child = TreeNode.new( tag, text, attrs)

                if reader
                    instance_variable_set( ("@" + tag.to_s).to_sym, child )

                __meta_id__.class_eval "
                        def #{child.__tag__}(&blk)
                            ret = @#{child.__tag__} 
                            if blk
                               ret.instance_eval &blk
                            end
                            ret
                        end"
                end

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
