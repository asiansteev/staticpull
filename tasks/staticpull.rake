# Copyright (c) 2010 Todd Willey <todd@rubidine.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

task :staticpull => ['staticpull:purge', 'staticpull:url', 'staticpull:import']

namespace :staticpull do

  task :purge => [:environment] do
    Page.destroy_all
    Upload.destroy_all
  end

  task :url do
    require 'uri'
    @url = ENV['URL']
    if @url.blank?
      abort(
        "Environment variable URL must be set: " +
        "URL=http://localhost/ rake staticpull"
      )
    end
    @uri = URI.parse(@url)
    if @uri.scheme.nil?
      @uri = URI.parse("http://#{@url}")
    end
  end

=begin
  task :download do
    require 'fileutils'
    dir = File.join(RAILS_ROOT, 'site_mirror')
    FileUtils.mkdir_p(dir)
    if File.exists?(File.join(dir, @uri.host)) and !ENV['FORCE']
      puts "skipping download\n" +
           ". desitination directory exists\n" +
           ". set FORCE=1 to force a new mirror operation"
    else
      `(cd #{dir} && wget --mirror #{@url})`
    end
  end
=end

  task :import => [:environment] do
    require 'uri'

=begin
    dir = File.join(RAILS_ROOT, 'site_mirror', @uri.host)
    unless Host.default.name == 'localhost'
      Host.default.update_attribute(:name, @uri.host)
    end
=end
    Staticpull.import(@uri.to_s)
  end
end
