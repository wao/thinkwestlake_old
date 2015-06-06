ThinWestLake.extension do
    node :simple do
        def configure(project)
            project.pom(:default).instance_exec do
                packaging :jar

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
