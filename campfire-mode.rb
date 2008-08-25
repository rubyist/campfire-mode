## campfire-mode.rb --- Major mode for Campfire

# Copyright (C) 2007 Scott Barron.

# Author: Scott Barron <scott@theedgecase.com>
# Created: Nov 20, 2007
# Version: $Rev: 121 $
# Keywords: campfire web
# URL: http://opensource.edgerepo.com/text/emacs/campfire-mode/README

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#; Commentary:

# campfire-mode.el is a major mode for Campfire.
# You can login to a campfire room and read and post messages in Emacs.

require 'singleton'
require 'rubygems'
gem 'tinder'
require 'tinder'

defvar :campfire_mode_map, make_sparse_keymap

defvar :campfire_timer, nil

defvar :campfire_timer_interval, 30

defvar :campfire_username, nil

defvar :campfire_password, nil

defvar :campfire_domain, nil

defvar :campfire_room, nil

defvar :campfire_username_face, :campfire_username_face

defvar :campfire_buffer, '*campfire*'
defun(:campfire_buffer) do
  campfire_get_or_generate_buffer campfire_buffer
end

defun(:campfire_get_or_generate_buffer) do |buffer|
  bufferp(buffer) ? buffer : generate_new_buffer(buffer)
end

if elvar.campfire_mode_map
  define_key elvar.campfire_mode_map, "\C-c\C-s", :campfire_speak
end

# Monkey patching tinder
class Tinder::Room
  attr_reader :user_name
  
  def join(force=false)
    @room = returning(get("room/#{id}")) do |room|
      raise Error, "Could not join room" unless verify_response(room, :success)
      @membership_key = room.body.scan(/\"membershipKey\": \"([a-z0-9]+)\"/).to_s
      @user_id = room.body.scan(/\"userID\": (\d+)/).to_s
      @user_name = room.body.scan(/\s*window\.chat(.*)/).to_s.scan(/<td class=\\"person\\"><span>(.+)<\/span>/).to_s
      @last_cache_id = room.body.scan(/\"lastCacheID\": (\d+)/).to_s
      @timestamp = room.body.scan(/\"timestamp\": (\d+)/).to_s
    end if @room.nil? || force
    true
  end
end
# End monkey patching tinder


class CampfireMode
  include Singleton
  include ElMixin
  
  def start
    @campfire = Tinder::Campfire.new elvar.campfire_domain
    @campfire.login elvar.campfire_username, elvar.campfire_password
    unless @room = @campfire.find_room_by_name(elvar.campfire_room)
      message "Could not find campfire room #{elvar.campfire_room}"
      return
    end
    @room.join

    transcript = @room.transcript(@room.available_transcripts.first)
    transcript.each do |msg|
      with(:with_current_buffer, elvar.campfire_buffer) do
        render_message(msg[:person], msg[:message])
      end
    end
    
    message "starting campfire"
    elvar.campfire_timer = run_at_time '0 sec', elvar.campfire_timer_interval, :campfire_update
  end

  def stop
    @room.leave
    @campfire.logout
    kill_buffer elvar.campfire_buffer # For some reason, don't use the function here
  end

  def speak(msg)
    @room.speak msg
    render_message @room.user_name, msg
  end

  def paste(msg)
    @room.paste msg
    render_message @room.user_name, msg
  end

  def update
    messages = @room.listen
    messages.each do |msg|
      render_message(msg[:person], msg[:message])
    end
  end

  def render_message(person, msg)
    return if person.blank?

    with(:with_current_buffer, elvar.campfire_buffer) do
      elvar.buffer_read_only = nil
      end_of_buffer

      # Look for inline images, uploads, and pastesxb
      if msg =~ /onload="loadInlineImage\(this\)"/
        msg =~ /img src="(.+)" alt/
        msg_text = "[Inline Image] #{$1}"
      elsif msg =~ /a href="(\/room\/\d+\/uploads\/\d+\/[^\s]+)"/
        msg_text = "[Upload] http://#{elvar.campfire_domain}.campfirenow.com#{$1}"
      elsif msg =~ /(\/room\/\d+\/paste\/\d+)/
        msg_text = "[Paste] http://#{elvar.campfire_domain}.campfirenow.com#{$1}\n"
        msg =~ /<pre><code>(.*)<\/code><\/pre>/m
        msg_text << $1
      else
        msg_text = msg
      end
      
      current_max = point_max
      insert "#{person}\n #{msg_text}\n\n"

      # Since I'm unable to add_text_properties to the string in el4r, calculate it for the
      # whole buffer using the point prior to insertion
      add_text_properties current_max, current_max + person.size, [:mouse_face, :highlight, :face, :campfire_username_face], get_buffer(elvar.campfire_buffer)
      
      elvar.buffer_read_only = true
      end_of_buffer
    end
  end
end

defun :campfire_mode_init_variables do
  # I can't figure out how to defface or set_face_attribute from el4r
  font_lock_mode -1
  el4r_lisp_eval "(defface campfire-username-face `((t nil)) "" :group 'face)"
  copy_face :font_lock_string_face, :campfire_username_face
  el4r_lisp_eval "(set-face-attribute 'campfire-username-face nil :underline t)"
end

defun(:campfire_update) do
  CampfireMode.instance.update
end

defun(:campfire_speak, :interactive => "sMessage: ") do |msg|
  CampfireMode.instance.speak(msg)
end

defun(:campfire_paste_region, :interactive => "r") do |first, last|
  CampfireMode.instance.paste(buffer_substring(first, last))
end

defun(:campfire_paste_buffer, :interactive => true) do
  CampfireMode.instance.paste(buffer_string)
end

defun(:campfire_stop, :interactive => true) do
  CampfireMode.instance.stop
  cancel_timer elvar.campfire_timer
end

defun(:campfire_mode, :docstring => "Major mode for Campfire", :interactive => true) do
  switch_to_buffer elvar.campfire_buffer
  kill_all_local_variables
  campfire_mode_init_variables
  use_local_map elvar.campfire_mode_map
  elvar.major_mode = :campfire_mode
  elvar.mode_name = "Campfire mode"
  campfire_mode_init_variables
  font_lock_mode -1
  begin
    CampfireMode.instance.start
  rescue Exception => e
    puts e.inspect
  end
end

provide(:campfire_mode)
