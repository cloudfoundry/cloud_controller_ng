require 'nokogiri'

module DocsHelpers
  def get_version
    version = File.exists?('source/versionfile') ? File.read('source/versionfile') : 'local'
    if version =~ /release-candidate/
      "Release Candidate"
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

    output = ""

    headings.each do |h1|
      output += "<ul class='tocify-header'>"
      output += "<li class='tocify-item' data-unique='#{h1[:id]}'><a>#{h1[:text]}</a></li>"

      if h1[:children].any?
        output += "<ul class='tocify-subheader' data-tag='2'>"

        h1[:children].each do |h2|
          output += "<li class='tocify-item' data-unique='#{h2[:id]}'><a>#{h2[:text]}</a></li>"

          if h2[:children].any?
            output += "<ul class='tocify-subheader' data-tag='3'>"

            h2[:children].each do |h3|
              output += "<li class='tocify-item' data-unique='#{h3[:id]}'><a>#{h3[:text]}</a></li>"
            end

            output += "</ul>"
          end
        end
      end

      output += "</ul>"
    end

    output += "</ul>"

    output
  end
end