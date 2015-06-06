require "thinwestlake/version"

module ThinWestLake
  # Your code goes here...
end

require 'thinwestlake/project'

TWL = ThinWestLake

#Load predefined extensions
require_relative '../extension/android'
require_relative '../extension/simple'
