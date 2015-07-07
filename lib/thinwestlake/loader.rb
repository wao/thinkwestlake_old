require 'thinwestlake'

module ThinWestLake
    # Help load TWLfile in filesystem and generate pom files for them
    class Loader
        attr_reader :parent, :current

        # Find the TWLFile in directory or parent of  directory
        # @param path [ Pathname ] Directory which is possible storing TWLFile
        def find_twlfile( path )
            tm_assert{ path.is_a? Pathname }
            file = path + "TWLfile"
            if file.exist?
                file
            else
                if path.root?
                    puts "Can't find TWLfile"
                    exit -1
                else
                    find_twlfile path.parent
                end
            end
        end

        # Load TWLFile and evaluate it
        def load_twlfile(file)
            tm_assert{ file.is_a? Pathname }
            tm_assert{ file.exist? }
            ThinWestLake::Project.last_instance = nil
            load file.to_s
            tm_assert{ ThinWestLake::Project.last_instance }
            ThinWestLake::Project.last_instance.twlpath file.parent
            ThinWestLake::Project.last_instance
        end

        def load_current_twlfile( current_path )
            file = find_twlfile( current_path )
            load_twlfile( file )
        end

        def load_all( current_path )
            @current = load_current_twlfile(current_path)
            if @current.has_parent?
                parent_file =  @current.twlpath.parent + "TWLfile"
                if !parent_file.exist?
                    puts "has_parent is defined. But TWLFile doesn't exist in parent directory #{@current.twlpath.parent}"
                    exit(-1)
                end

                @parent = load_twlfile( @current.twlpath.parent + "TWLfile" )
            end
        end

        def scan_and_add_subtwl( parent_project )
            parent_project.twlpath.each_child do |f|
                if f.directory?
                    twlfile = f + "TWLfile"
                    if twlfile.exist?
                        subtwl = load_twlfile( twlfile )
                        if subtwl.has_parent?
                            parent_project.pom(:root).mymodule( f.basename, nil )
                        end
                    end
                end
            end
        end

        def generate_all(filemgr)
            tm_assert{ filemgr }
            @current.configure
            scan_and_add_subtwl( @current )

            if @parent
                @parent.configure
                @current.pom(:root).parent( @parent.pom(:root) )

                scan_and_add_subtwl( @parent )
                @parent.pom(:root).packaging( :pom )
                @parent.generate( filemgr )
            end
            @current.generate( filemgr )
        end
    end
end
