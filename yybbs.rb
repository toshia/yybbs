# frozen_string_literal: true

require_relative 'model/server'
require_relative 'model/world'
require_relative 'model/user'
require_relative 'model/message'
require 'nokogiri'

Plugin.create(:yybbs) do
  tab(:yybbs, "yybbs") do
    timeline :yybbs
  end

  defspell(:around_message, :yybbs_message) do |message|
    Thread.new do
      result = [message, message.thread].compact
      ancestor = result.last

      doc = URI.open("#{ancestor.server.uri}?res=#{ancestor.id}&bbs=1&pg=0", &Nokogiri::HTML.method(:parse))
      _thread, *res = doc.at_css('div#main-in').css('.art').map { |art|
        get_art_bbs1(art, ancestor.server)
      }
      res.each do |r|
        r.thread = ancestor
      end
      [ancestor, *res]
    end
  end

  defspell(:compose, :yybbs) do |world, body:, **opts|
    doc = URI.open("#{world.server.uri}?bbs=0", &Nokogiri::HTML.method(:parse))
    str_crypt = doc.at_css('input[name="str_crypt"]').attribute('value').value
    captcha_url = File.dirname(world.server.uri.to_s) + '/' + doc.at_css('img.capt').attribute('src').value.gsub(%r<\A./>, '')
    captcha_photo = Plugin.filtering(:photo_filter, captcha_url, [])[1].first

    dialog('投稿') {
      label '以下の画像に表示されている数字を入力してください。'
      link captcha_photo
      input '画像認証', :captcha
    }.next { |result|
      sub, comment = body.split("\n", 2)
      Net::HTTP.post_form(URI.parse("#{File.dirname(world.server.uri.to_s)}/regist.cgi"),
                          { mode: 'regist',
                            reno: '',
                            bbs: '0',
                            name: world.name || '',
                            email: '',
                            sub: sub,
                            comment: comment,
                            url: '',
                            icon: world.icon_index || '0',
                            pwd: world.password || '',
                            captcha: result[:captcha],
                            str_crypt: str_crypt,
                            color: world.color || '0',
                          })
    }
  end

  world_setting(:yybbs, "yybbs") do
    self[:url] = 'https://d250g2.com/yybbs/yybbs.cgi'
    self[:password] = SecureRandom.alphanumeric(rand(6..9))
    label "BBSのURLを指定してください(yybbs.cgi まで入れてください)"
    input 'URL', :url
    url = await_input[:url]
    doc = URI.open("#{url}?mode=icon", &Nokogiri::HTML.method(:parse))

    input '名前', :name
    input '暗証キー', :password

    select('アイコン', :icon) do
      doc.css('#pop-icon img').each_with_index do |img, index|
        #[img.attribute('src').value, img.parent.next_element.content]
        icon_url = File.dirname(url) + '/' + img.attribute('src').value.gsub(%r<\A./>, '')
        option([index, icon_url], img.parent.next_element.content)
      end
    end

    select('文字色', :color, {
             "0" => "#800000",
             "1" => "#df0000",
             "2" => "#008040",
             "3" => "#0000ff",
             "4" => "#c100c1",
             "5" => "#ff80c0",
             "6" => "#ff8040",
             "7" => "#000080",
             "8" => "#808000",
           })

    result = await_input

    world = Plugin::YYBBS::World.new(
      slug: "yybbs_#{url}_#{SecureRandom.uuid}",
      name: result[:name],
      password: result[:password],
      icon_index: result[:icon][0],
      icon_url: result[:icon][1],
      color: result[:color],
      url: url
    )
    if world
      label 'このサーバを登録しますか？'
      label world.to_s
      world
    else
      Deferred.next{ Deferred.fail('サーバに接続できませんでした') }
    end
  end

  def polling
    Plugin.collect(:worlds).select { |w| w.class.slug == :yybbs }.map(&:server).uniq.each do |server|
      doc = URI.open("#{server.uri}?bbs=0") do |io|
        Nokogiri::HTML.parse(io)
      end
      doc.at_css('div.ta-c').css('.art').map { |art|
        timeline(:yybbs) << get_art_bbs0(art, server)
      }
    end
    Delayer.new(delay: 60) { polling }
  end

  def get_art_bbs0(art, server)
    icon_node = art.at_css('img.image')
    parent = Plugin::YYBBS::Message.new(
      { id: art.at_css('.art-info .num').content.match(/No.(\d+)/)&.[](1).to_i,
        title: art.at_css('strong')&.content,
        body: icon_node.next_element.content, # TODO: 改行考える
        created: art.at_css('.art-info img[alt="time.png"]')&.next&.content&.yield_self(&Time.method(:parse)),
        user: {
          server: server,
          username: art.at_css('.art-info b').content,
          icon_path: icon_node&.attribute('src')&.value
        }
      })
    result = [parent]
    art.css('.reslog').each do |res|
      icon_node = res.at_css('img.image')
      result << Plugin::YYBBS::Message.new(
        { id: res.at_css('.art-info .num').content.match(/No.(\d+)/)&.[](1).to_i,
          title: res.at_css('strong')&.content,
          body: icon_node.next_element.content, # TODO: 改行考える
          created: res.at_css('.art-info img[alt="time.png"]')&.next&.content&.yield_self(&Time.method(:parse)),
          thread: parent,
          user: {
            server: server,
            username: res.at_css('.art-info b').content,
            icon_path: icon_node&.attribute('src')&.value
          }
        })
    end
    result
  end

  def get_art_bbs1(art, server)
    icon_node = art.at_css('img.image')
    parent = Plugin::YYBBS::Message.new(
      { id: art.attribute('id').value.to_i,
        title: art.at_css('strong')&.content,
        body: art.at_css('span.num').next_element.at_css('span').content, # TODO: 改行考える
        created: art.at_css('b')&.next&.content&.yield_self { |str|
          Time.parse(str.match(%r<投稿日：(.+)\z>)[1])
        },
        user: {
          server: server,
          username: art.at_css('b').content,
          icon_path: icon_node&.attribute('src')&.value
        }
      })
    parent
  end

  Delayer.new(delay: 5) { polling }
end
