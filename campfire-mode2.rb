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

defvar :campfire_username, nil
defvar :campfire_password, nil
defvar :campfire_domain,   nil
defvar :campfire_room,     nil

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
# End tinder monkey patch


class CampfireMode < ElApp
  def initialize(x={})
    @mode_map       = make_sparse_keymap
    @timer          = nil
    @timer_interval = 30
    @buffer         = "*campfire*"

    define_key @mode_map, "\C-c\C-s", :campfire_speak
  end
end
