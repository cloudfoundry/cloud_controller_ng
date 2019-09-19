require 'nokogiri'

module DocsHelpers
  def current_version
    version = File.exist?('source/versionfile') ? File.read('source/versionfile') : 'local'
    if version =~ /release-candidate/
      'Release Candidate'
    else
      "Version #{version}"
    end
  end

  def extract_table_of_contents(html)
    page = Nokogiri::HTML(html)

    headings = []
    page.css('h1,h2,h3').each do |heading|
      headings.push({
        id: heading.attribute('id').to_s,
        text: heading.content,
        level: heading.name[1].to_i,
        children: []
      })
    end

    [3, 2].each do |heading_level|
      heading_to_nest = nil
      headings = headings.reject do |heading|
        if heading[:level] == heading_level
          heading_to_nest[:children].push heading if heading_to_nest
          true
        else
          heading_to_nest = heading if heading[:level] == (heading_level - 1)
          false
        end
      end
    end

    output = ''

    headings.each do |h1|
      output += "<ul class='toc-header'>"
      output += "<li class='toc-item'><a class='toc-link' href='\##{h1[:id]}'>#{h1[:text]}</a></li>"

      if h1[:children].any?
        output += "<ul class='toc-subheader'>"

        h1[:children].each do |h2|
          output += "<li class='toc-item'><a class='toc-link' href='\##{h2[:id]}'>#{h2[:text]}</a></li>"

          if h2[:children].any?
            output += "<ul class='toc-subheader'>"

            h2[:children].each do |h3|
              output += "<li class='toc-item'><a class='toc-link' href='\##{h3[:id]}'>#{h3[:text]}</a></li>"
            end

            output += '</ul>'
          end
        end
      end

      output += '</ul>'
    end

    output += '</ul>'

    output
  end
end
