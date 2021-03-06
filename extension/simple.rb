ThinWestLake.extension do
    node :simple do
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

                dependency "org.projectlombok:lombok" do
                    version "1.16.4"
                    scope "provided"
                end

                dependency "junit:junit" do
                    version "4.11"
                    scope "provided"
                end

                dependency "com.google.guava:guava" do
                    version "18.0"
                end

                dependency "info.thinkmore.android:cofoja-api" do
                    version "1.2-SNAPSHOT"
                end

                dependency "info.thinkmore.android:cofoja" do
                    version "1.2-SNAPSHOT"
                    scope :provided
                end
            end

            super
        end

    end
end
