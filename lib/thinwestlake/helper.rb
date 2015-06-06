module ThinWestLake
    module AttrRw
        module ClassMethods
            def attr_rw( *args )
                args.each do |arg|
                    def_accessor( arg )
                end
            end

            def def_accessor( attr_name )
                self.class_eval "
                    def #{attr_name}(value=nil) 
                        if value.nil?
                            @#{attr_name}
                        else
                            #puts \"#{attr_name}=\#{value}\"
                            @#{attr_name} = value
                            self
                        end
                    end"
            end
        end

        def self.included(mod)
            class << mod
                self.include(ClassMethods)
            end
        end
    end
end
