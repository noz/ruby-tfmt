class TFmt

  VERSION = "0.0.6"

  def format lines
    lines = lines.lines.map {|l| l.chomp } unless lines.is_a? Array

    title = lines.shift
    title ||= ""
    title.strip!

    # read header lines
    hdr = {}
    loop {
      break unless lines.first =~ /^([^\s:]+)\s*:(.*)$/
      hdr[$1.strip.downcase] = $2.strip
      lines.shift
    }

    body = []
    toc = []
    tocid = 1

    loop {
      line = lines.shift
      break unless line

      if line.match? /^\s*---+$/

        # verbatim block

        pre = []
        loop {
          l = lines.shift
          break unless l
          break if l.match? /^\s*---+$/
          pre.push l
        }

        body.push %|<pre class="verbatim round-border">|,
                  # indent by 2 spaces
                  *pre.map {|l| "  " + untabify(hesc l).chomp },
                  "</pre>"
        pre = nil

      elsif line.match? /^\s*\|/

        # table

        tab = []
        l = line
        loop {
          tab.push l
          l = lines.shift
          break unless l
          unless l.match? /^\s*\|/
            lines.unshift l
            break
          end
        }

        tab.map! {|row|
          cols = row.gsub(/\|([^|]*)/) {
            "<td>#{keepspace untabify hesc $1}</td>"
          }
          [ "<tr>", *cols, "</tr>" ].join "\n"
        }

        body.push %|<table border="1" class="border">|,
                  *tab,
                  %|</table>|

      elsif line =~ /^(=+)\s+(.+)$/

        # section

        slev = $1.length
        stitle = $2

        xslev = [ slev + 2, 6 ].min

        body.push %|<h#{xslev} id="sec-#{tocid}" class="section-title">#{format_line stitle}</h#{xslev}>|

        toc.push [ "sec-#{tocid}", stitle, slev ]
        tocid += 1

      elsif line =~ /^-\s+(.+)\s*$/

        # definition list head

        body.push %|<span class="def gothic">#{format_line $1}</span><br/>|

      elsif line.empty?

        # empty line

        body.push %|<br class="empty-textline"/>|

      else

        # ordinary lines

        body.push %|<span class="textline">#{keepspace untabify format_line line}</span><br/>|
      end
    }

    [ title, body, toc, hdr ]
  end

  def hesc s
    s.gsub(/([&<>"])/, { "<" => "&lt;", ">" => "&gt;",
                         "&" => "&amp;", '"' => "&quot;" })
  end

  NOENCODE = []
  "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ().'*-_/"
    .each_byte {|c| NOENCODE.push c.ord }

  def uenc s
    ret = ""
    s.each_byte {|c|
      ret << (NOENCODE.include?(c) ? c.chr : "%%%02X" % c)
    }
    ret.tr(" ", "+")	# space -> +
  end

  TOKOPEN = {
    "<b>" => %|<b class="bold">|,
    "<i>" => "<i>",
    "<u>" => "<u>",
    "<t>" => "<kbd>",
  }
  TOKCLOSE = {
    "</b>" => "</b>",
    "</i>" => "</i>",
    "</u>" => "</u>",
    "</t>" => "</kbd>",
  }

  def format_line line
    ret = ""
    loop {
      tok, txt, line = read_until line, /(?:<\/?[biut]>|{(?:[a-z][a-z0-9_]*)?:)/i

      ret << inline_url(txt)
      break unless tok

      if tok =~ /{([a-z][a-z0-9_]*)?:/
        plugin = $1 || "url"
        if (_, argpart, line = read_until line, "}").first
          ret << call_plugin(plugin, argpart)
        else
          ret << %|<span class="plugin-error">{#{hesc plugin}:#{hesc argpart} UNCLOSED</span>|
        end
      else
        if (x = TOKOPEN[tok])
          ret << "#{x}#{format_line line}"
          break
        elsif (x = TOKCLOSE[tok])
          ret << x
        end
      end
    }
    ret
  end
  private :format_line

  URL_RE = %r!((?:https?|ftp)://(?:[-\da-z\.]+)\.[a-z\.]+(?:[-/\w\.%:=~]*)/?(?:#[-\w\.=]*)?(?:[\?&][-/\w\.=%+\&#:,]*)?)!

  def inline_url s
    ret = ""
    while s =~ URL_RE
      ret << hesc(Regexp.last_match.pre_match)
      ret << %|<a class="gothic" href="#{$1}">#{hesc $1}</a>|
      s = Regexp.last_match.post_match
    end
    ret << hesc(s)
  end
  private :inline_url

  def call_plugin plugin, argpart
    args = []
    s = argpart
    loop {
      sep, arg, post = read_until s, "|"
      args.push arg.strip
      break unless sep
      s = post
    }

    pmeth = "plugin_#{plugin}".intern
    if respond_to? pmeth
      begin
        send pmeth, args
      rescue => ex
        %|<span class="plugin-error"> {#{hesc plugin}:#{hesc argpart}} PLUGIN ERROR - #{hesc ex.message}】</span>|
      end
    else
      %|<span class="plugin-error"> {#{hesc plugin}:#{hesc argpart}} UNKNOWN PLUGIN</span>|
    end
  end
  private :call_plugin

  def plugin_link args
    url = args[0]
    anchor = args[1] || url
    %|<a class="gothic" href="#{hesc url}">#{hesc anchor}</a>|
  end

  def plugin_thumb args
    path, width = args

    pathl = path.rpartition "/"
    pathl[1] = "thumb"

    if width
      swidth = %| width="#{hesc width}"|
    else
      swidth = %||
    end

    pathl.shift if pathl.first.empty? && path[0] != "/"

    %|<a href="#{uenc path}"><img class="solid-border"#{swidth} src="#{uenc File.join pathl}.jpg"/></a>|
  end

  def plugin_pic args
    path = args.first
    %|<a href="#{uenc path}"><img class="solid-border" src="#{uenc path}"/></a>|
  end

  def plugin_audio args
    path = args.first

    %|<audio class="" src="#{uenc path}" controls="controls" preload="none"></audio>|
  end

  def plugin_video args
    path = args.first

    pathl = path.rpartition "/"
    pathl[1] = "thumb"

    pathl.shift if pathl.first.empty? && path[0] != "/"

    %|<video class="solid-border" src="#{uenc path}" poster="#{uenc File.join pathl}.jpg" controls="controls" preload="none"></video>|
  end

  def keepspace s
    s.gsub(/(^ +| +$)/) { "&nbsp;" * $1.length }
  end

  def read_until str, re
    pre = ""
    while true
      p0, tok, str = str.partition re

      if tok.empty?
        pre = "#{pre}#{p0}"
        tok = nil
        break
      end

      if p0[-1] == "\\"
        if p0[-2] == "\\"
          pre << p0
          pre[-1] = ""
          break
        else
          pre << p0
          pre[-1] = ""
          pre << tok
          next
        end
      else
        pre << p0
        break
      end
    end
    [ tok, pre, str ]
  end
  private :read_until

  def untabify s
    pre = ""
    s.gsub(/(\t+|[^\t]*)/) {
      if $1[0] == "\t"
        " " * ((string_width($1) * 8) - (string_width(pre) % 8))
      else
        pre = $1
      end
    }
  end
  private :untabify

  def string_width s
    s.each_char.map {|c| c.ascii_only? ? 1 : 2 }.inject(:+) || 0
  end
  private :string_width

end
