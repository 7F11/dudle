############################################################################
# Copyright 2009,2010 Benjamin Kellermann                                  #
#                                                                          #
# This file is part of dudle.                                              #
#                                                                          #
# Dudle is free software: you can redistribute it and/or modify it under   #
# the terms of the GNU Affero General Public License as published by       #
# the Free Software Foundation, either version 3 of the License, or        #
# (at your option) any later version.                                      #
#                                                                          #
# Dudle is distributed in the hope that it will be useful, but WITHOUT ANY #
# WARRANTY; without even the implied warranty of MERCHANTABILITY or        #
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public     #
# License for more details.                                                #
#                                                                          #
# You should have received a copy of the GNU Affero General Public License #
# along with dudle.  If not, see <http://www.gnu.org/licenses/>.           #
############################################################################

require "time"
require "log"

class VCS
	GITCMD="git"
	def VCS.init
		%x{#{GITCMD} init}
	end

	def VCS.rm file
		%x{#{GITCMD} rm #{file}}
	end

	def VCS.add file
		%x{#{GITCMD} add #{file}}
	end

	def VCS.revno
		# there is a bug in git log --format, which supresses the \n on the last line
		%x{#{GITCMD} log --format="format:x"}.scan("\n").size + 1
	end

	def VCS.cat revision, file
		revs = %x{#{GITCMD} log --format=format:%H}.scan(/^(.*)$/).flatten.reverse
		%x{#{GITCMD} show #{revs[revision-1]}:#{file}}
	end

	def VCS.history
		log = %x{#{GITCMD} log --format=format:"%s\t%ai"}.split("\n").reverse
		ret = Log.new
		log.each_with_index{|s,i|
			a = s.scan(/^([^\t]*)(.*)$/).flatten
			ret.add(i+1, Time.parse(a[1]), a[0])
		}
		ret
	end

	def VCS.commit comment
		tmpfile = "/tmp/commitcomment.#{rand(10000)}"
		File.open(tmpfile,"w"){|f|
			f<<comment
		}
		ret = %x{#{GITCMD} commit -a -F #{tmpfile}}
		File.delete(tmpfile)
		ret
	end
	
	def VCS.branch source, target
		%x{#{GITCMD} clone #{source} #{target}}
	end

	def VCS.revert revno
		revhash = %x{#{GITCMD} log --format=%H}.split("\n").reverse[revno-1]
		%x{#{GITCMD} checkout #{revhash} .}
		VCS.commit("Reverted Poll to version #{revno}")
	end
end


