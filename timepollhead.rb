############################################################################
# Copyright 2009-2019 Benjamin Kellermann                                  #
#                                                                          #
# This file is part of Dudle.                                              #
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

# BUGFIX for Time.parse, which handles the zone indeterministically
class << Time
	alias old_parse parse
	def Time.parse(date, _now = now)
		Time.old_parse('2009-10-25 00:30')
		Time.old_parse(date)
	end
end

require_relative 'timestring'

class TimePollHead
	def initialize
		@data = []
	end

	def col_size
		@data.size
	end

	# returns a sorted array of all columns
	#	column should be the internal representation
	#	column.to_s should deliver humanreadable form
	def columns
		@data.sort.collect { |day| day.to_s }
	end

	def concrete_times
		h = {}
		@data.each { |ds| h[ds.time_to_s] = true }
		h.keys
	end

	def date_included?(date)
		ret = false
		@data.each { |ds|
			ret ||= ds.date == date
		}
		ret
	end

	# deletes one concrete column
	# adds the empty day, if it was the last concrete time of the day
	# returns true if deletion successful
	def delete_concrete_column(col)
		ret = !@data.delete(col).nil?
		@data << TimeString.new(col.date, nil) unless date_included?(col.date)
		ret
	end

	# column is in human readable form
	# returns true if deletion successful
	def delete_column(column)
		if $cgi.include?('togglealloff') # delete one time
			head_count('%Y-%m-%d', false).each { |day, _num|
				delete_concrete_column(TimeString.new(day, column))
			}
			return true
		end
		col = TimeString.from_s(column)
		return delete_concrete_column(col) if col.time

		# delete all concrete times on the given day
		deldata = []
		@data.each { |ts|
			deldata << ts if ts.date == col.date
		}
		deldata.each { |ts|
			@data.delete(ts)
		}
		!deldata.empty?
	end

	def parsecolumntitle(title)
		if $cgi.include?('add_remove_column_day')
			parsed_date = YAML.load(Time.parse("#{$cgi['add_remove_column_month']}-#{$cgi['add_remove_column_day']} #{title}").to_yaml)
		else
			earlytime = @head.keys.collect { |t| t.strftime('%H:%M') }.sort[0]
			parsed_date = YAML.load(Time.parse("#{$cgi['add_remove_column_month']}-#{title} #{earlytime}").to_yaml)
		end
		parsed_date
	end

	# returns parsed title or nil in case of column not changed
	def edit_column(column, newtitle, cgi)
		if cgi.include?('toggleallon')
			head_count('%Y-%m-%d', false).each { |day, _num|
				parsed_date = TimeString.new(day, newtitle)
				delete_column(day) if @data.include?(TimeString.new(day, nil))
				@data << parsed_date unless @data.include?(parsed_date)
			}
			return newtitle
		end
		if cgi.include?('columntime') && cgi['columntime'] == ''
			@edit_column_error = _('To add a time other than the default times, please enter some string here (e.&thinsp;g., 09:30, morning, afternoon).')
			return nil
		end
		delete_column(column) if column != ''
		parsed_date = TimeString.new(newtitle, cgi['columntime'] == '' ? nil : cgi['columntime'])
		if @data.include?(parsed_date)
			@edit_column_error = _('This time has already been selected.')
			nil
		else
			@data << parsed_date
			parsed_date.to_s
		end
	end

	# returns a sorted array, containing the big units and how often each small is in the big one
	# small and big must be formatted for strftime
	# ex: head_count("%Y-%m") returns an array like [["2009-03",2],["2009-04",3]]
	# if notime = true, the time field is stripped out before counting
	def head_count(elem, notime)
		data = @data.collect { |day| day.date }
		data.uniq! if notime
		ret = Hash.new(0)
		data.each { |day|
			ret[day.strftime(elem)] += 1
		}
		ret.sort
	end

	def to_html(scols, _config = false, _activecolumn = nil)
		ret = "<tr><th colspan='2' class='invisible'></th>"
		head_count('%Y-%m', false).each { |title, count|
			year, month = title.split('-').collect { |e| e.to_i }
			ret += "<th colspan='#{count}'>#{Date.parse("#{year}-#{month}-01").strftime('%b %Y')}</th>\n"
		}

		ret += "<th class='invisible'></th></tr><tr><th colspan='2' class='invisible'></th>"
		head_count('%Y-%m-%d', false).each { |title, count|
			ret += "<th colspan='#{count}'>#{Date.parse(title).strftime('%a, %d')}</th>\n"
		}

		def sortsymb(scols, col)
			<<-SORTSYMBOL
				<span class="sortsymb visually-hidden headerSymbol">#{scols.include?(col) ? _('Sort') : _('No Sort')}</span>
				<span class='sortsymb' aria-hidden='true'> #{scols.include?(col) ? SORT : NOSORT}</span>
			SORTSYMBOL
		end

		ret += "<th class='invisible'></th></tr><tr><th colspan='2'><a href='?sort=name'>" + _('Name') + " #{sortsymb(scols, 'name')}</a></th>"
		@data.sort.each { |date|
			ret += "<th class='polloptions'><a title=\"#{CGI.escapeHTML(date.to_s)}\" href=\"?sort=#{CGI.escape(date.to_s)}\">#{CGI.escapeHTML(date.time_to_s)} #{sortsymb(scols, date.to_s)}</a></th>\n"
		}
		ret += "<th><a href='?'>" + _('Last edit') + " #{sortsymb(scols, 'timestamp')}</a></th>\n</tr>\n"
		ret
	end

	def datenavi(val, revision)
		case val
		when MONTHBACK
			navimonth = Date.parse("#{@startdate.strftime('%Y-%m')}-1") - 1
			navimonthDescription = _('Navigate one month back')
		when MONTHFORWARD
			navimonth = Date.parse("#{@startdate.strftime('%Y-%m')}-1") + 31
			navimonthDescription = _('Navigate one month forward')
		else
			raise "Unknown navi value #{val}"
		end
		<<END
		<th colspan='2' style='padding:0px'>
			<form method='post' action=''>
				<div>
					<input class='navigation' type='submit' title='#{navimonthDescription}' aria-label='#{navimonthDescription}' value='#{val}' />
					<input type='hidden' name='add_remove_column_month' value='#{navimonth.strftime('%Y-%m')}' />
					<input type='hidden' name='firsttime' value='#{@firsttime.to_s.rjust(2, '0')}:00' />
					<input type='hidden' name='lasttime' value='#{@lasttime.to_s.rjust(2, '0')}:00' />
					<input type='hidden' name='undo_revision' value='#{revision}' />
				</div>
			</form>
		</th>
END
	end

	def timenavi(val, revision)
		case val
		when EARLIER
			return '' if @firsttime == 0

			str = EARLIER + ' ' + _('Earlier')
			strAria = _('Add previous two hours')
			firsttime = [@firsttime - 2, 0].max
			lasttime = @lasttime
		when LATER
			return '' if @lasttime == 23

			str = LATER + ' ' + _('Later')
			strAria = _('Add following two hours')
			firsttime = @firsttime
			lasttime = [@lasttime + 2, 23].min
		else
			raise "Unknown navi value #{val}"
		end
		<<END
<tr>
	<td class='navigation' colspan='2'>
		<form method='post' action=''>
			<div>
				<input class='navigation' type='submit' title='#{strAria}' aria-label='#{strAria}' value='#{str}' />
				<input type='hidden' name='firsttime' value='#{firsttime.to_s.rjust(2, '0')}:00' />
				<input type='hidden' name='lasttime' value='#{lasttime.to_s.rjust(2, '0')}:00' />
				<input type='hidden' name='add_remove_column_month' value='#{@startdate.strftime('%Y-%m')}' />
				<input type='hidden' name='undo_revision' value='#{revision}' />
			</div>
		</form>
	</td>
</tr>
END
	end

	def edit_column_htmlform(_activecolumn, revision)
		# calculate start date, first and last time to show
		if $cgi.include?('add_remove_column_month')
			@startdate = Date.parse("#{$cgi['add_remove_column_month']}-1")
		else
			@startdate = Date.parse("#{Date.today.year}-#{Date.today.month}-1")
		end

		times = concrete_times
		times.delete('') # do not display empty cell in edit-column-form
		realtimes = times.collect { |t|
			begin
				Time.parse(t) if t =~ /^\d\d:\d\d$/
			rescue ArgumentError
			end
		}.compact
		[9, 16].each { |i| realtimes << Time.parse("#{i.to_s.rjust(2, '0')}:00") }

		%w[firsttime lasttime].each { |t|
			realtimes << Time.parse($cgi[t]) if $cgi.include?(t)
		}

		@firsttime = realtimes.min.strftime('%H').to_i
		@lasttime  = realtimes.max.strftime('%H').to_i

		def add_remove_button(klasse, buttonlabel, action, columnstring, revision, pretext = '', _arialabel = columnstring, properdate)
			if %w[chosen delete].include?(klasse)
				titlestr = format(_('Delete the column %<DATE>s'), DATE: CGI.escapeHTML(properdate))
				if klasse == 'delete'
					klasse += ' headerSymbol'
				end
			elsif klasse == 'disabled'
				titlestr = format(_('Add the already past column %<DATE>s'), DATE: CGI.escapeHTML(properdate))
			else
				titlestr = format(_('Add the column %<DATE>s'), DATE: CGI.escapeHTML(properdate))
			end
			<<FORM
<form method='post' action=''>
	<div>
		#{pretext}<input date="#{CGI.escapeHTML(properdate)}" title='#{titlestr}' aria-label='#{titlestr}' class='#{klasse}' type='submit' value="#{buttonlabel}" />
		<input type='hidden' name='#{action}' value="#{CGI.escapeHTML(columnstring)}" />
		<input type='hidden' name='firsttime' value="#{@firsttime.to_s.rjust(2, '0')}:00" />
		<input type='hidden' name='lasttime' value="#{@lasttime.to_s.rjust(2, '0')}:00" />
		<input type='hidden' name='add_remove_column_month' value="#{@startdate.strftime('%Y-%m')}" />
		<input type='hidden' name='undo_revision' value='#{revision}' />
	</div>
</form>
FORM
		end

		hintstr = _('Click on the dates to add or remove columns.')
		ret = <<END
<table style='width:100%'><tr><td style="vertical-align:top">
<div id='AddRemoveColumndaysDescription' class='shorttextcolumn'>
#{hintstr}
</div>
<table border='1' class='calendarday'><tr>
END
		ret += datenavi(MONTHBACK, revision)
		ret += "<th colspan='3'>#{@startdate.strftime('%b %Y')}</th>"
		ret += datenavi(MONTHFORWARD, revision)

		ret += "</tr><tr>\n"

		7.times { |i|
			# 2010-03-01 was a Monday, so we can use this month for a dirty hack
			ret += "<th class='weekday'>#{Date.parse("2010-03-0#{i + 1}").strftime('%a')}</th>"
		}
		ret += "</tr></thead><tr>\n"

		((@startdate.wday + 7 - 1) % 7).times {
			ret += "<td class='invisible'></td>"
		}
		d = @startdate
		while true
			klasse = 'notchosen'
			varname = 'new_columnname'
			klasse = 'disabled' if d < Date.today
			if date_included?(d)
				klasse = 'chosen'
				varname = 'deletecolumn'
			end
			ret += "<td class='calendarday'>#{add_remove_button(klasse, d.day, varname, d.strftime('%Y-%m-%d'), revision, d.strftime('%d-%m-%Y'))}</td>"
			d = d.next
			break if d.month != @startdate.month

			ret += "</tr><tr>\n" if d.wday == 1
		end
		_('added')
		_('removed')
		ret += <<END
</tr></table>
<div id="liveCalenderDayInfo" class="shorttextcolumn visually-hidden" aria-live="assertive"></div>
</td>
END

		###########################
		# starting hour input
		###########################
		ret += "<td style='vertical-align:top'>"
		if col_size > 0
			optstr = _('Optional:')
			hintstr = _('Select specific start times.')
			ret += <<END
<div id='ConcreteColumndaysDescription' class='shorttextcolumn'>
#{optstr}<br/>
#{hintstr}
</div>
<table border='1' class='calendarday calendartime timecolumns'>
<thead>
<tr>
END

			ret += "<td class='invisible' colspan='2'></td>"
			head_count('%Y-%m', true).each { |title, count|
				year, month = title.split('-').collect { |e| e.to_i }
				ret += "<th colspan='#{count}'>#{Date.parse("#{year}-#{month}-01").strftime('%b %Y')}</th>\n"
			}

			ret += "</tr><tr><th colspan='2'>" + _('Time') + '</th>'

			head_count('%Y-%m-%d', true).each { |title, _count|
				coltime = Date.parse(title)
				ret += '<th>' + add_remove_button('delete', DELETE, 'deletecolumn', coltime.strftime('%Y-%m-%d'), revision, "#{coltime.strftime('%a, %d')}&nbsp;", coltime.strftime('%d-%m-%Y')) + '</th>'
			}

			ret += '</thead></tr>'

			days = @data.sort.collect { |date| date.date }.uniq

			chosenstr = {
				'chosen' => _('Selected'),
				'notchosen' => _('Not selected'),
				'disabled' => _('Past')
			}

			ret += timenavi(EARLIER, revision)

			(@firsttime..@lasttime).each { |i| times << "#{i.to_s.rjust(2, '0')}:00" }
			times.flatten.compact.uniq.sort { |a, b|
				if a =~ /^\d\d:\d\d$/ && !(b =~ /^\d\d:\d\d$/)
					-1
				elsif !(a =~ /^\d\d:\d\d$/) && b =~ /^\d\d:\d\d$/
					1
				else
					a.to_i == b.to_i ? a <=> b : a.to_i <=> b.to_i
				end
			}.each { |time|
				ret += <<END
		<tr>
			<td class='navigation'>#{CGI.escapeHTML(time)}</td>
			<td class='navigation' style='padding:0px'>
				<form method='post' action='' accept-charset='utf-8'>
					<div>
						<input type='hidden' name='add_remove_column_month' value='#{@startdate.strftime('%Y-%m')}' />
						<input type='hidden' name='firsttime' value='#{@firsttime.to_s.rjust(2, '0')}:00' />
						<input type='hidden' name='lasttime' value='#{@lasttime.to_s.rjust(2, '0')}:00' />
						<input type='hidden' name='undo_revision' value='#{revision}' />
END
				# check, if some date of the row is unchecked
				if head_count('%Y-%m-%d', false).collect { |day, _num|
					@data.include?(TimeString.new(day, time))
				}.include?(false)
					# toggle all on
					ret += "<input type='hidden' name='toggleallon' value='true' />"
					ret += "<input type='hidden' name='new_columnname' value=\"#{CGI.escapeHTML(time)}\" />"
					titlestr = _('Select the whole row')
				else
					# toggle all off
					ret += "<input type='hidden' name='togglealloff' value='true' />"
					ret += "<input type='hidden' name='deletecolumn' value=\"#{CGI.escapeHTML(time)}\" />"
					titlestr = _('Deselect the whole row')
				end
				ret += "<input type='submit' class='toggle' title='#{titlestr}' aria-label='#{titlestr}' value='#{MONTHFORWARD}' />"
				ret += <<END
					</div>
				</form>
			</td>
END
				days.each { |day|
					timestamp = TimeString.new(day, time)
					klasse = 'notchosen'
					klasse = 'disabled' if timestamp < TimeString.now

					if @data.include?(timestamp)
						klasse = 'chosen'
						hiddenvars = "<input type='hidden' name='deletecolumn' value=\"#{CGI.escapeHTML(timestamp.to_s)}\" />"
					else
						hiddenvars = "<input type='hidden' name='new_columnname' value=\"#{timestamp.date}\" />"
						if @data.include?(TimeString.new(day, nil)) # change day instead of removing it if no specific hour exists for this day
							hiddenvars += "<input type='hidden' name='columnid' value=\"#{TimeString.new(day, nil)}\" />"
						end
					end
					ret += '<td>' + add_remove_button(klasse, chosenstr[klasse], 'columntime', CGI.escapeHTML(timestamp.time_to_s), revision, hiddenvars, timestamp.to_s) + '</td>'
				}
				ret += "</tr>\n"
			}
			ret += timenavi(LATER, revision)

			ret += "<tr><td colspan='2' class='invisible'></td>"
			days.each { |d|
				ret += <<END
	<td class='addColumnManual'>
		<form method='post' action='' accept-charset='utf-8'>
			<div>
				<input type='hidden' name='new_columnname' value='#{d.strftime('%Y-%m-%d')}' />
				<input type='hidden' name='add_remove_column_month' value='#{d.strftime('%Y-%m')}' />
				<input type='hidden' name='firsttime' value='#{@firsttime.to_s.rjust(2, '0')}:00' />
				<input type='hidden' name='lasttime' value='#{@lasttime.to_s.rjust(2, '0')}:00' />
				<input type='hidden' name='undo_revision' value='#{revision}' />
END
				if @data.include?(TimeString.new(d, nil))
					ret += "<input type='hidden' name='columnid' value='#{TimeString.new(d, nil)}' />"
				end
				addstr = _('Add')
				hintstr = _('e.&thinsp;g., 09:30, morning, afternoon')
				timestr = _('Write a specific time for ')
				ret += <<END
				<input type="text" name='columntime' title='#{timestr}#{d.strftime('%d-%m-%Y')}' aria-label='#{timestr}#{d.strftime('%d-%m-%Y')}' style="max-width: 10ex" /><br />
				<input type="submit" value="#{addstr}" style="width: 100%" />
			</div>
		</form>
	</td>
END
			}

			ret += '</tr></table>'
			ret += "<div class='error textcolumn'>#{@edit_column_error}</div>" if @edit_column_error
		end
		ret += '</td></tr></table>'
		ret
	end
end
