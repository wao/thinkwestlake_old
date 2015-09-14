ThinWestLake.extension do
    node :android do
        def configure( project )
            enable_processor_plugin = true
            root = ThinWestLake::Maven::Pom.new( project.pom(:root).gid, (project.pom(:root).aid.to_s + "-parent").to_sym, project.version ) do
                packaging "pom"

                name "#{project.pom(:root).aid.to_s} - Parent"

                property "android.proguard.skip", "false"

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

                if enable_processor_plugin
                    plugin_mgr "org.codehaus.mojo:build-helper-maven-plugin" do
                        version "1.9.1"
                        config do
                            execution.as_list do
                                execution do
                                    id "add-test-source"
                                    phase "generate-test-sources"
                                    goal.as_list do
                                        goal "add-test-source"
                                    end
                                    configuration do
                                        source.as_list do
                                            source "src/main/java"
                                            source "target/generated-sources/apt"
                                            source "target/generated-sources/r"
                                        end
                                    end
                                end
                            end
                        end
                    end

                    plugin_mgr "org.bsc.maven:maven-processor-plugin" do
                        version "2.0.5"
                        config do
                            execution.as_list do
                                execution do
                                    id "process"
                                    goal.as_list do
                                        goal "process"
                                    end
                                    phase "generate-sources"
                                    configuration do
                                        compilerArguments "-sourcepath target/generated-sources/r"
                                    end
                                end
                                execution do
                                    id "process-test"
                                    goal.as_list do
                                        goal "process-test"
                                    end
                                    phase "generate-test-sources"
                                    configuration do
                                        compilerArguments "-sourcepath target/generated-sources/r"
                                    end
                                end
                            end
                        end
                    end
                end


                dependency_mgr "android.support:compatibility-v4" do
                    version "22.0.0"
                end

                #dependency_mgr "com.google.android:support-v4" do
                #version "19.0.1"
                #scope "system"
                #config do
                #systemPath "${env.ANDROID_HOME}/extras/android/support/v4/android-support-v4.jar"
                #end
                #end

                dependency_mgr "org.robolectric:robolectric" do
                    version "3.0-rc3"
                    scope "test"
                end

                dependency_mgr "junit:junit" do
                    version "4.11"
                    scope "provided"
                end

                dependency_mgr "info.thinkmore:simple-assert" do
                    version "1.0-SNAPSHOT"
                end

                dependency_mgr "com.google.guava:guava" do
                    version "18.0"
                end

                plugin_mgr "com.simpligility.maven.plugins:android-maven-plugin" do
                    version "4.3.0"
                    config do
                        extensions "true"
                        configuration do
                            sdk do
                                platform "21"
                            end

                            resourceDirectory "res"
                            androidManifestFile "AndroidManifest.xml"

                            proguard do
                                skip "${android.proguard.skip}"
                                jvmArgument.as_list do
                                    jvmArgument "-Xms256m"
                                    jvmArgument "-Xmx512m"
                                end
                            end

                        end
                    end

                    dependency "net.sf.proguard:proguard-base" do
                        version "4.8"
                    end
                end

                plugin_mgr "org.apache.maven.plugins:maven-compiler-plugin" do
                    version "3.3"
                    configuration do
                        source "1.7"
                        target "1.7"
                        if enable_processor_plugin
                            useIncrementalCompilation "true"
                            compilerArgument "-proc:none"
                        else
                            useIncrementalCompilation "false"
                        end
                    end
                end

                #plugin_mgr "info.thinkmore:cofoja-maven-plugin" do
                #version "1.0-SNAPSHOT"

                #config do
                #executions do
                #execution do
                #id "default-cli"
                #phase "compile"
                #goals do
                #goal "run"
                #end
                #end
                #end
                #end
                #end

                dependency_mgr "info.thinkmore.android:cofoja-api" do
                    version "1.2-SNAPSHOT"
                end

                #dependency_mgr "info.thinkmore.android:cofoja" do
                #version "1.2-SNAPSHOT"
                #scope :provided
                #end

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
                                        goal.as_list do
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

            old_root = project.pom(:root)
            project.pom(:root, root)

            test_prj = ThinWestLake::Maven::Pom.new( old_root.gid, "#{old_root.aid}-it", old_root.version ) do
                parent project.pom(:root)
                packaging :apk
                name "#{aid} - Integration tests"

                dependency "com.google.code.findbugs:jsr305"
                dependency "org.androidannotations:androidannotations-api"

                dependency "com.google.android:android-test" do
                    version "4.1.1.4"
                    scope :provided
                end

                dependency "com.jayway.android.robotium:robotium-solo" do
                    version "5.0.1"
                end

                dependency "android.support:compatibility-v4"
                #dependency "com.google.android:support-v4"

                #My using pom directory
                dependency "#{old_root.gid}:#{old_root.aid}" do
                    version old_root.version
                    type "apk"
                end

                dependency "#{old_root.gid}:#{old_root.aid}" do
                    version old_root.version
                    scope  :provided
                    type "jar"
                end

                plugin "com.simpligility.maven.plugins:android-maven-plugin" do
                    configuration do
                        #TODO fix it
                        mytest do
                            createReport true
                        end
                    end
                end
            end

            old_root.instance_exec do
                parent project.pom(:root)

                packaging :apk
                name "#{aid}"

                dependency "info.thinkmore.android:cofoja-api"
                #dependency "info.thinkmore.android:cofoja"
                dependency "com.google.guava:guava"
                dependency "android:android"
                dependency "org.androidannotations:androidannotations"
                dependency "org.androidannotations:androidannotations-api"
                #dependency "com.google.android:support-v4" 
                dependency "android.support:compatibility-v4"
                dependency "org.robolectric:robolectric"
                dependency "junit:junit"
                dependency "com.google.code.findbugs:jsr305"
                dependency "info.thinkmore:simple-assert"
                if enable_processor_plugin
                    plugin "org.codehaus.mojo:build-helper-maven-plugin" 
                    plugin "org.bsc.maven:maven-processor-plugin"
                end

                #plugin "info.thinkmore:cofoja-maven-plugin"

                plugin "com.simpligility.maven.plugins:android-maven-plugin" 
                #do
                    #configuration do
                        #proguard do
                            #skip false
                            #jvmArgument.as_list do
                                #jvmArgument "-Xms256m"
                                #jvmArgument "-Xmx512m"
                            #end
                        #end
                    #end

                    #dependency "net.sf.proguard:proguard-base" do
                        #version "4.8"
                    #end
                #end

                plugin "org.apache.maven.plugins:maven-compiler-plugin"

                profile do
                    config do
                        id :release
                        activation do
                            property do
                                name :performRelease
                                value true
                            end
                        end

                        properties do
                            __new_node__( "android.release".to_sym, true )
                            __new_node__( "android.apk.debug".to_sym, false )
                            __new_node__( "apk.raw".to_sym, "${project.build.directory}/${project.artifactId}-${project.version}.apk" )
                            __new_node__( "apk.signed.aligned".to_sym, "${project.build.directory}/${project.artifactId}-${project.version}-signed-aligned.apk" )
                        end
                    end

                    plugin "org.apache.maven.plugins:maven-jarsigner-plugin" do
                        version "1.4"

                        config do
                            executions do
                                execution do
                                    id :sign
                                    goal.as_list do
                                        goal :sign
                                        goal :verify
                                    end
                                    phase :package
                                    inherited true
                                    configuration do
                                        includes do
                                            include "${apk.raw}"
                                        end
                                    end
                                end
                            end
                        end
                    end

                    plugin "com.simpligility.maven.plugins:android-maven-plugin" do
                        version "4.1.1"

                        config do
                            inherited true
                            configuration do
                                sign do
                                    debug false
                                end
                                zipalign do
                                    skip false
                                    verbose true
                                    inputApk "${apk.raw}"
                                    outputApk "${apk.signed.aligned}"
                                end
                            end
                            executions do
                                execution do
                                    id :alignApk
                                    phase :package
                                    goals do
                                        goal :zipalign
                                    end
                                end
                            end
                        end
                    end
                end
            end

            project.pom(:root).mymodule( old_root.aid.to_s, old_root )
            project.pom(:root).mymodule( test_prj.aid.to_s, test_prj )
            project.pom(:test, test_prj )

            super
        end
    end
end
