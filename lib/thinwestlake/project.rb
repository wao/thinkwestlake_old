require 'metaid'
require 'byebug'
require 'simple_assert'
require 'thinwestlake/maven/pom'

module ThinWestLake
    class Node
        def initialize
            @prop = {}
            @node = {}
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
        attr_accessor :gid, :aid, :version
        attr_accessor :default_pom, :root_pom

        def initialize(gid, aid, version)
            tm_assert{ gid && aid }
            super()
            @gid = gid.to_sym
            @aid = aid.to_sym
            @version = version
        end

        meta_eval do
            attr_accessor :root
        end

        def configure
            tm_assert{ @version }
            @root_pom = Maven::Pom.new( @gid, @aid, @version )
            @default_pom = @root_pom

            @node.each_value do |v|
                v.configure( self )
            end
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
            create_pom( file_mgr, root_pom )
            root_pom.modules.each_pair do |p,v|
                create_pom( file_mgr, v, p )
            end
        end
    end

    def self.project( gid, aid, version=nil, &block )
        if Project.root
            raise ArgumentError.new("Only one project definition can exist!") 
        end

        Project.root = Project.new( gid, aid, version )
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

    class Project
        node :android do
            def configure( project )
                root = Maven::Pom.new( project.root_pom.gid, (project.root_pom.aid.to_s + "-parent").to_sym, project.version ) do
                    packaging "pom"

                    name "#{project.root_pom.aid.to_s} - Parent"

                    dependency "org.projectlombok:lombok" do
                        version "1.16.4"
                        scope "provided"
                    end

                    dependency_mgr "android:android" do
                        version "5.0.1_r2"
                        scope "provided"
                    end

                    dependency_mgr "com.google.code.findbugs:jsr305" do
                        version "3.0.0"
                        scope :provided
                    end

                    dependency_mgr "org.androidannotations:androidannotations" do
                        version "3.2"
                        scope "provided"
                    end


                    dependency_mgr "org.androidannotations:androidannotations-api" do
                        version "3.2"
                    end

                    dependency_mgr "com.google.android:support-v4" do
                        version "r7"
                    end

                    dependency_mgr "org.robolectric:robolectric" do
                        version "2.4"
                        scope "test"
                    end

                    dependency_mgr "junit:junit" do
                        version "4.11"
                        scope "provided"
                    end

                    dependency_mgr "com.google.guava:guava" do
                        version "18.0"
                    end

                    plugin_mgr "com.simpligility.maven.plugins:android-maven-plugin" do
                        version "4.1.1"
                        config do
                            extensions "true"
                            configuration do
                                sdk do
                                    platform "21"
                                end

                                resourceDirectory "res"
                                androidManifestFile "AndroidManifest.xml"
                            end
                        end
                    end

                    plugin_mgr "org.apache.maven.plugins:maven-compiler-plugin" do
                        version "3.3"
                        configuration do
                            source "1.7"
                            target "1.7"
                            useIncrementalCompilation "false"
                        end
                    end

                    dependency_mgr "info.thinkmore.android:cofoja-api" do
                        version "1.2-SNAPSHOT"
                    end

                    dependency_mgr "info.thinkmore.android:cofoja" do
                        version "1.2-SNAPSHOT"
                        scope :provided
                    end

                    plugin_mgr "org.eclipse.m2e:lifecycle-mapping" do
                        version "1.0.0"
                        configuration do
                            lifecycleMappingMetadata do
                                pluginExecutions do
                                    pluginExecution do
                                        pluginExecutionFilter do
                                            groupId "com.simpligility.maven.plugins"
                                            artifactId "android-maven-plugin"
                                            versionRange "[3.8.2,)"
                                            goals do
                                                goal "consume-aar"
                                                goal "emma"
                                            end
                                        end
                                        action do
                                            ignore
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                old_root = project.root_pom
                project.root_pom = root

                test_prj = Maven::Pom.new( old_root.gid, "#{old_root.aid}-it", old_root.version ) do
                    parent project.root_pom
                    packaging :apk
                    name "#{aid} - Integration tests"

                    dependency "com.google.android:android-test" do
                        version "4.1.1.4"
                        scope :provided
                    end

                    dependency "com.jayway.android.robotium:robotium-solo" do
                        version "5.0.1"
                    end

                    #My using pom directory
                    dependency "#{old_root.gid}:#{old_root.aid}" do
                        version old_root.version
                        type :apk
                        scope  :provided
                    end

                    dependency "#{old_root.gid}:#{old_root.aid}" do
                        version old_root.version
                        type :jar
                        scope  :provided
                    end

                    plugin "com.simpligility.maven.plugins:android-maven-plugin" 
                    #do
                    #configuration do
                    ##TODO fix it
                    ##test do
                    ##createReport true
                    ##end
                    #end
                    #end
                end

                old_root.instance_exec do
                    parent project.root_pom

                    packaging :apk
                    name "#{aid}"

                    dependency "info.thinkmore.android:cofoja-api"
                    dependency "info.thinkmore.android:cofoja"
                    dependency "com.google.guava:guava"
                    dependency "android:android"
                    dependency "org.androidannotations:androidannotations"
                    dependency "com.google.android:support-v4" 
                    dependency "org.robolectric:robolectric"
                    dependency "junit:junit"
                    dependency "com.google.code.findbugs:jsr305"

                    plugin "com.simpligility.maven.plugins:android-maven-plugin" do
                        configuration do
                            proguard do
                                skip false
                                jvmArguments do
                                    jvmArgument "-Xms256m"
                                    jvmArgument "-Xmx512m"
                                end
                            end
                        end

                        dependency "net.sf.proguard:proguard-base" do
                            version "4.8"
                        end
                    end
                end

                project.root_pom.module( old_root.aid.to_s, old_root )
                project.root_pom.module( test_prj.aid.to_s, test_prj )
            end
        end
    end
end
