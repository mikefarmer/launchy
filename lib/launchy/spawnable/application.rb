require 'launchy/spawnable'
require 'rbconfig'

module Launchy
    module Spawnable
        class Application
            
            KNOWN_OS_FAMILIES = [ :windows, :darwin, :nix ]
            
            class << self
                def inherited(sub_class)
                    application_classes << sub_class
                end            
                def application_classes
                    @application_classes ||= []
                end                
                
                def find_application_class_for(*args)
                    Launchy.log "finding application classes for [#{args.join(' ')}]"
                    application_classes.find do |klass| 
                        if klass.handle?(*args) then
                            Launchy.log "  #{klass.name}"
                            true
                        else
                            false
                        end
                    end
                end
                
                # Determine the appropriate desktop environment for *nix machine.  Currently this is
                # linux centric.  The detection is based upon the detection used by xdg-open from 
                # http://portland.freedesktop.org/wiki/XdgUtils
                def nix_desktop_environment
                    de = :generic
                    if ENV["KDE_FULL_SESSION"] || ENV["KDE_SESSION_UID"] then
                        de = :kde
                    elsif ENV["GNOME_DESKTOP_SESSION_ID"] then
                        de = :gnome
                    elsif find_executable("xprop") then
                        if %x[ xprop -root _DT_SAVE_MODE | grep ' = \"xfce\"$' ].strip.size > 0 then
                            de = :xfce
                        end
                    end
                    Launchy.log "nix_desktop_environment => #{de}"
                    return de
                end
                
                # find an executable in the available paths
                # mkrf did such a good job on this I had to borrow it.
                def find_executable(bin,*paths)
                    paths = ENV['PATH'].split(File::PATH_SEPARATOR) if paths.empty?
                    paths.each do |path|
                        file = File.join(path,bin)
                        if File.executable?(file) then
                            Launchy.log "found executable #{file}"
                            return file
                        end
                    end
                    Launchy.log "Unable to find `#{bin}' in paths #{paths.join(', ')}"
                    return nil
                end
                
                # return the current 'host_os' string from ruby's configuration
                def my_os
                    ::Config::CONFIG['host_os']
                end
            
                # detect what the current os is and return :windows, :darwin or :nix
                def my_os_family(test_os = my_os)
                    case test_os
                    when /mswin/i
                        family = :windows
                    when /windows/i
                        family = :windows
                    when /darwin/i
                        family = :darwin
                    when /mac os/i
                        family = :darwin
                    when /solaris/i
                        family = :nix
                    when /bsd/i
                        family = :nix
                    when /linux/i
                        family = :nix
                    when /cygwin/i
                        family = :nix
                    else
                        $stderr.puts "Unknown OS familiy for '#{test_os}'.  Please report this bug."
                        family = :unknown
                    end
                end
            end
            
            # find an executable in the available paths
            def find_executable(bin,*paths)
                Application.find_executable(bin,*paths)
            end
            
            # return the current 'host_os' string from ruby's configuration
            def my_os
                Application.my_os
            end
            
            # detect what the current os is and return :windows, :darwin or :nix
            def my_os_family(test_os = my_os)
                Application.my_os_family(test_os)
            end
            
            # run the command
            def run(cmd,*args)
                args.unshift(cmd)
                cmd_line = args.join(' ')
                Launchy.log "Spawning on #{my_os_family} : #{cmd_line}"
                if my_os_family == :windows then
                    system cmd_line
                else
                    # fork and the child process should NOT run any exit handlers
                    child_pid = fork do 
                                    system cmd_line
                                    exit! 
                                end
                    Process.detach(child_pid)
                end
            end
        end
    end
end
