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
    pp 'pass!!!'
    Thread.new do
      result = [message, message.thread].compact
    end
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
      doc.at_css('div.ta-c').css('.art').map { |x|
        icon_node = x.at_css('img.image')
        parent = Plugin::YYBBS::Message.new(
          { id: x.at_css('.art-info .num').content.match(/No.(\d+)/)&.[](1).to_i,
            title: x.at_css('strong')&.content,
            body: icon_node.next_element.content, # TODO: 改行考える
            created: x.at_css('.art-info img[alt="time.png"]')&.next&.content&.yield_self(&Time.method(:parse)),
            user: {
              server: server,
              username: x.at_css('.art-info b').content,
              icon_path: icon_node&.attribute('src')&.value
            }
          })
        x.css('.reslog').each do |res|
          icon_node = res.at_css('img.image')
          timeline(:yybbs) << Plugin::YYBBS::Message.new(
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
        timeline(:yybbs) << parent
      }
    end
    Delayer.new(delay: 60) { polling }
  end

  Delayer.new(delay: 5) { polling }
end
