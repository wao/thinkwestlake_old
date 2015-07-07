require 'minitest/autorun'
require 'shoulda/context'
require 'minitest/reporters'
require 'minitest/mock'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new # spec-like progress

class XmlElem
    def initialize(elem)
        @elem = elem
    end

    def elem( path, &blk )
        if blk.nil?
            XmlElem.new( REXML::XPath.first( @elem, path ) )
        else
            REXML::XPath.each( @elem, path ) do |e|
                blk.call( XmlElem.new(e) )
            end
        end
    end

    def as_xml
        @elem
    end

    def as_text
        @elem.text
    end

    def text( path, &blk )
        if blk.nil?
            elem( path ).as_text
        else
            elem( path ) do |e|
                blk.call( e.as_text )
            end
        end
    end

    def dump
        @elem.write
    end
end

class XmlDoc < XmlElem
    def initialize( pom )
        #byebug
        if pom.is_a? String
            super( REXML::Document.new pom )
        else
            super( REXML::Document.new pom.to_xml.target! )
        end
    end
end
