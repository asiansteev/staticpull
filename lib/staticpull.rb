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

##
# Import directories
#
class Staticpull
  class << self
    
    def import url 
      @host = Host.default
      @domain = url
      import_page(url)
    end
    
    def import_page url
    p "========================="
    p "URL: #{url}"
      require 'mechanize'
      mech = Mechanize.new
      src_page = mech.get(url)
      
      imgs = src_page.search("img[@src]").map {|src|
        if of_domain?(src['src'])
          standardize_url(src['src'])
        else
          nil
        end
      } || []
      imgs.compact!
      imgs.uniq!
      
      css = src_page.search("link[@href]").map {|href|
        if of_domain?(href['href'])
          standardize_url(href['href'])
        else
          nil
        end
      } || []
      css.compact!
      css.uniq!
      
      pages = [standardize_url url]
      pages.concat src_page.search("a[@href]").map {|href|
        # the url is everything before the '#'
        tmp_url = href['href'].split('#')[0] || ''
        if tmp_url.empty? # no url 
          nil
        elsif tmp_url == @domain
          nil
        elsif is_img? tmp_url and of_domain?(tmp_url) # url is image
          imgs << standardize_url(tmp_url)
          nil
        elsif is_js? tmp_url # url is javascript
          nil
        elsif tmp_url[0, 7] == 'mailto:' # url is email address
          nil
        else # url is a url!!
          standardize_url tmp_url
        end
      }.compact!
      pages.uniq!

      p "imgs: [#{imgs*', '}]"
      p "css: [#{css*', '}]"
      p "pages: [#{pages*', '}]"
     
      path = (url + '/')[@domain.length .. -1]
      slug = File.basename(path)
      parent = find_or_create_parent(File.dirname(path))

      page = nil
      if empty_parent?(parent) and (slug =~ /index/ or slug == '/')
        page = parent
        page.http_status = '200'
      else
        page = Page.new(
                 :host => @host,
                 :path => standardize_url(path),
                 :name => slug.humanize,
                 :slug => slug,
                 :http_status => 200,
                 :content_type => 'text/html',
                 :parent => parent
               )
      end

      unless page.save
        alert_unsaved_page(page)
        return
      end

      block = page.page_blocks.new(
                :name => 'main',
                :body => src_page.body, 
                :published_at => Time.now
              )
      block.save || alert_unsaved_block(block)


      imgs.each do |i|
        unless Upload.find_by_upload_file_name(File.basename i)
          import_asset "#{@domain}#{i}"
        end
      end
      
      pages.each do |p|
        unless Page.find_by_slug(File.basename p)
          import_page "#{@domain}#{p}"
        end
      end
      
      css.each do |c|
        unless Page.find_by_slug(File.basename c)
          import_css "#{@domain}#{c}"
        end
      end

    end

    def import_css url
    p "========================="
    p "URL: #{url}"
      require 'mechanize'
      mech = Mechanize.new
      src_page = mech.get(url)
     
      path = (url + '/')[@domain.length .. -1]
      slug = File.basename(path)
      parent = find_or_create_parent(File.dirname(path))
      
      css = [] 
      src_page.body.each do |p|
        if p =~ /@import url/
          fn = p.split("\"")[1]
          css << "#{parent}/#{fn}"
        end
      end

      imgs = [] 
      src_page.body.each do |p|
        if p =~ /background/ and p =~ /url/
          if p =~ /\"/
            fn = "#{parent}/#{p.split("\"")[1]}"
            fn = File.expand_path(fn)
            imgs << fn
          else
            fn = "#{parent}/#{p.split("(")[1].split(")")[0]}"
            fn = File.expand_path(fn)
            imgs << fn
          end
        end
      end

      p "imgs: [#{imgs*', '}]"
      p "css: [#{css*', '}]"

      page = nil
      if empty_parent?(parent) and (slug =~ /index/ or slug == '/')
        page = parent
        page.http_status = '200'
      else
        page = Page.new(
                 :host => @host,
                 :path => standardize_url(path),
                 :name => slug.humanize,
                 :slug => slug,
                 :http_status => 200,
                 :content_type => 'text/css',
                 :parent => parent
               )
      end

      unless page.save
        alert_unsaved_page(page)
        return
      end

      block = page.page_blocks.new(
                :name => 'main',
                :body => src_page.body, 
                :published_at => Time.now
              )
      block.save || alert_unsaved_block(block)


      imgs.each do |i|
        unless Upload.find_by_upload_file_name(File.basename i)
          import_asset "#{@domain}#{i}"
        end
      end
      
      css.each do |c|
        unless Page.find_by_slug(File.basename c)
          import_css "#{@domain}#{c}"
        end
      end

    end

    def import_asset url
      path = (url + '/')[@domain.length .. -1]
      slug = File.basename(path)
      parent = find_or_create_parent(File.dirname(path))

      asset = Upload.new(
                :upload => open(url),
                :host => @host,
                :published_at => Time.now
              )
      unless asset.save
        alert_unsaved_asset(asset)
        return
      end

      ftype = case File.extname(url).downcase
      when '.jpg' then 'image/jpeg'
      when '.jpeg' then 'image/jpeg'
      when '.gif' then 'image/gif'
      when '.png' then 'image/png'
      else 'text/html'
      end

      page = Page.new(
               :host => @host,
               :parent => parent,
               :path => path,
               :name => slug.humanize,
               :slug => slug,
               :http_status => 200,
               :content_type => ftype,
               :page_logic_behavior => 'PageLogicBehavior::PermanentRedirect'
             )
      page.add_behaviors
      page.redirect_url = asset.attachment_for(:upload).url
      page.save || alert_unsaved_page(page)
    end

    def find_or_create_parent path
      p = Page[@host, path, true]
      return p if p
      p = Page.create(
            :host => @host,
            :slug => File.basename(path),
            :path => path,
            :name => File.basename(path).humanize,
            :parent => ((path == '/') ? \
                         nil : \
                         find_or_create_parent(File.dirname(path))),
            :http_status => 404
          )
      if p.new_record?
        alert_unsaved_parent(p)
      end
      p
    end

    def empty_parent? page
      !page.named_block('main')
    end

    def alert_unsaved_page page
      puts "UNABLE TO SAVE PAGE: #{page.name} # #{page.path}"
      p page.attributes
      puts page.errors.full_messages.join("\n\t")
      puts "-----------------"
    end

    def alert_unsaved_block block
      puts "UNABLE TO SAVE BLOCK: #{block.name} # #{block.page.path}"
      puts block.errors.full_messages.join("\n\t")
      puts "-----------------"
    end
    
    def standardize_url url
      if is_relative_url? url
        if url[0, 1] == '/'
          url
        else
          '/' + url
        end
      elsif of_domain? url
        if url == @domain
          '/'
        else
          url[@domain.length, url.length]
        end
      end
    end

    def is_img? url
      url.match(/(jpg|gif|png|jpeg)\z/i) ? true : false
    end

    def is_js? url
      url[0, 10].downcase == 'javascript' ? true : false
    end

    def of_domain? url
      if is_relative_url? url and !is_js? url
        true
      else
        url[0, @domain.length] == @domain ? true : false
      end
    end

    def is_relative_url? url
      if url[0, 4].downcase != 'http'
        true
      else
        false
      end
    end

  end
end
