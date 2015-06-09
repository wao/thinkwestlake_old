ThinWestLake.extension do
    node :barebone do
        def configure(project)
            project.pom(:default).instance_exec do
                packaging :jar

                plugin_mgr "org.apache.maven.plugins:maven-compiler-plugin" do
                    version "3.3"
                    configuration do
                        source "1.7"
                        target "1.7"
                        useIncrementalCompilation "false"
                    end
                end

                dependency "junit:junit" do
                    version "4.11"
                    scope "provided"
                end
            end
            
            super
        end
    end
end
