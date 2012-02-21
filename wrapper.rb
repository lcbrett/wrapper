#!/usr/bin/env ruby
#
# FILE
#	wrapper.rb
#
# DESCRIPTION
#	Generic wrapper to enable pre- and post-commands.
#
# AUTHOR
#	L. Cliff Brett 2/2012
#

require 'yaml'
require 'pathname'
require 'fileutils'


class Wrapper
   attr_accessor :yamlFileName
   attr_accessor :executable

   def initialize(yamlFileName = nil, argv = nil)
      @yamlFileName = yamlFileName
      set_cmd_args(argv)
      config
   end

   def set_cmd_args(argv)
      @cmdArgs = argv.join(" ")
   end
      
   def config
      if !@yamlFileName.nil?
         @yamlFile = File.new(@yamlFileName)
         @config = YAML.load(@yamlFile)
         @yamlFile.close
         
         @executable = @config["command"]["executable"]
         @config.delete("command")

         @wrapperOutFile, @wrapperOut = config_wrapper_io("stdout",1)
         @wrapperErrFile, @wrapperErr = config_wrapper_io("stderr",2)
         @config.delete("wrapper")
      end
   end


   # Build a redirection string for stdout or stderr per ini file spec.
   # Make the directory path if needed.
   def config_wrapper_io(name,fd)
      @io = ""
      # @ioFile = @ini.param("wrapper",name)
      @ioFile = @config["wrapper"][name]
      if !@ioFile.nil?
         @ioDir = Pathname.new(@ioFile).dirname
         @ioDir.mkpath
         @io = " #{fd}>> "
         @io.concat(@ioFile)
      end
      return @ioFile, @io
   end

   
   def execute
      @pre = nil
      @post = nil
      @config.each do |section, settings| 
	 if /^\/.*\/$/ =~ section 
	    # Each section now specifies a pattern for the incoming command line args.
	    # Get rid of the leading and trailing /'s.
	    @cmdSpec = section.sub(/^\//,"")
	    @cmdSpec = @cmdSpec.sub(/\/$/,"")
            @cmdRe = Regexp.new(@cmdSpec)

	    # Look for pre- and post- commands if we have a match.
	    if @cmdRe.match(@cmdArgs)
	       @pre = settings["pre"]
	       @post = settings["post"]

	       # Capture any required args from the incoming command line.
	       @captureArgs = @cmdRe.names
	       @captureArgs.each do |captureArg|
	          @captureVal = @cmdRe.match(@cmdArgs)[:"#{captureArg}"]

		  # Substitute captured args in pre- and/or post-commands.
		  if !@captureVal.nil? 
		     @captureSpec = "<#{captureArg}>"
		     @captureRe = Regexp.new("<#{captureArg}>")
		     if !@pre.nil?
		        @pre = @pre.gsub(@captureRe,@captureVal)
		     end
		     if !@post.nil?
		        @post = @post.gsub(@captureRe,@captureVal)
		     end
		  end
	       end
	       break
	    end
	 end
      end

      # Execute the pre-command if there is one
      if !@pre.nil?
         @pre.concat("#{@wrapperOut}#{@wrapperErr}")
	 system @pre
	 @status = $?.exitstatus
	 if @status != 0
	    exit @status
	 end
      end

      # Execute the wrapped command.
      @cmd = "#{@executable} #{@cmdArgs}"
      system @cmd
      @status = $?.exitstatus
      if @status != 0
	 exit @status
      end

      # Execute the post-command if there is one.
      if !@post.nil?
         @post.concat("#{@wrapperOut}#{@wrapperErr}")
	 system @post
	 @status = $?.exitstatus
	 if @status != 0
	    exit @status
	 end
      end
   end

end
   


if __FILE__ == $PROGRAM_NAME
   wrap = Wrapper.new(ENV['WRAP_YAML'], ARGV)
   wrap.execute
end

