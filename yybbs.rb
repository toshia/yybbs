# frozen_string_literal: true

require_relative 'model/server'
require_relative 'model/world'
require_relative 'model/user'
require_relative 'model/message'
require 'nokogiri'

Plugin.create(:yybbs) do
  BIG_DATA = { 198 =>
          { 33 => [0],
            115 => [1],
            214 => [2],
            165 => [3],
            255 => [4],
            66 => [5, 8],
            16 => [6],
            132 => [7],
            74 => [9] },
               648 =>
          { 33 => [0],
            0 => [1, 2],
            198 => [3],
            132 => [4],
            107 => [5],
            74 => [6],
            16 => [7],
            41 => [8],
            66 => [9] } }.freeze

  tab(:yybbs, 'yybbs') do
    timeline :yybbs
  end

  defspell(:around_message, :yybbs_message) do |message|
    Thread.new do
      thread = message.ancestor

      doc = URI.open("#{thread.server.uri}?res=#{thread.id}&bbs=1&pg=0", &Nokogiri::HTML.method(:parse))
      _thread, *res = doc.at_css('div#main-in').css('.art').map do |art|
        get_art_bbs1(art, thread.server)
      end
      res.each do |r|
        r.thread = thread
      end
      [thread, *res]
    end
  end

  defspell(:compose, :yybbs, :yybbs_message) do |world, message, body:, **_opts|
    get_regist_token(world).next { |str_crypt, captcha_photo|
      [str_crypt, +verify_captcha(captcha_photo)]
    }.next do |str_crypt, captcha|
      request = {
        **world.gen_regist_payload,
        mode: 'regist',
        reno: message.ancestor.id,
        bbs: '0',
        sub: "Re: #{message.ancestor.title}".yield_self { |x| x.size > 15 ? "#{x[0..14]}…" : x },
        comment: body,
        captcha: captcha,
        str_crypt: str_crypt
      }
      res = +Thread.new { Net::HTTP.post_form(URI.parse("#{File.dirname(world.server.uri.to_s)}/regist.cgi"), request).tap(&:body) }
      post_error_check(request, res, message)
    end
  end

  defspell(:compose, :yybbs) do |world, body:, **_opts|
    get_regist_token(world).next { |str_crypt, captcha_photo|
      [str_crypt, +verify_captcha(captcha_photo)]
    }.next do |str_crypt, captcha|
      sub, comment = body.split("\n", 2)
      request = {
        **world.gen_regist_payload,
        mode: 'regist',
        reno: '',
        bbs: '0',
        sub: sub,
        comment: comment,
        captcha: captcha,
        str_crypt: str_crypt
      }
      res = +Thread.new { Net::HTTP.post_form(URI.parse("#{File.dirname(world.server.uri.to_s)}/regist.cgi"), request).tap(&:body) }
      post_error_check(request, res)
    end
  end

  world_setting(:yybbs, 'yybbs') do
    self[:url] = 'https://d250g2.com/yybbs/yybbs.cgi'
    self[:password] = SecureRandom.alphanumeric(rand(6..9))
    label 'BBSのURLを指定してください(yybbs.cgi まで入れてください)'
    input 'URL', :url
    url = await_input[:url]
    doc = URI.open("#{url}?mode=icon", &Nokogiri::HTML.method(:parse))

    input '名前', :name
    input '暗証キー', :password

    select('アイコン', :icon) do
      doc.css('#pop-icon img').each_with_index do |img, index|
        # [img.attribute('src').value, img.parent.next_element.content]
        icon_url = "#{File.dirname(url)}/#{img.attribute('src').value.gsub(%r<\A./>, '')}"
        option([index, icon_url], img.parent.next_element.content)
      end
    end

    select('文字色', :color, {
             '0' => '#800000',
             '1' => '#df0000',
             '2' => '#008040',
             '3' => '#0000ff',
             '4' => '#c100c1',
             '5' => '#ff80c0',
             '6' => '#ff8040',
             '7' => '#000080',
             '8' => '#808000'
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
      Deferred.next { Deferred.fail('サーバに接続できませんでした') }
    end
  end

  def polling
    Plugin.collect(:worlds).select { |w| w.class.slug == :yybbs }.map(&:server).uniq.each do |server|
      doc = URI.open("#{server.uri}?bbs=0") do |io|
        Nokogiri::HTML.parse(io)
      end
      doc.at_css('div.ta-c').css('.art').map do |art|
        timeline(:yybbs) << get_art_bbs0(art, server)
      end
    end
    Delayer.new(delay: 60) { polling }
  end

  def get_art_bbs0(art, server)
    icon_node = art.at_css('img.image')
    id = art.at_css('.art-info .num').content.match(/No.(\d+)/)&.[](1).to_i
    parent = Plugin::YYBBS::Message.new(
      { id: id,
        title: art.at_css('strong')&.content,
        body: icon_node.next_element.content, # TODO: 改行考える
        created: art.at_css('.art-info img[alt="time.png"]')&.next&.content&.yield_self(&Time.method(:parse)),
        user: {
          post_number: id,
          server: server,
          username: art.at_css('.art-info b').content,
          icon_path: icon_node&.attribute('src')&.value
        } }
    )
    result = [parent]
    art.css('.reslog').each do |res|
      icon_node = res.at_css('img.image')
      id = res.at_css('.art-info .num').content.match(/No.(\d+)/)&.[](1).to_i
      result << Plugin::YYBBS::Message.new(
        { id: id,
          title: res.at_css('strong')&.content,
          body: icon_node.next_element.content, # TODO: 改行考える
          created: res.at_css('.art-info img[alt="time.png"]')&.next&.content&.yield_self(&Time.method(:parse)),
          thread: parent,
          user: {
            post_number: id,
            server: server,
            username: res.at_css('.art-info b').content,
            icon_path: icon_node&.attribute('src')&.value
          } }
      )
    end
    result
  end

  def get_art_bbs1(art, server)
    icon_node = art.at_css('img.image')
    id = art.attribute('id').value.to_i
    Plugin::YYBBS::Message.new(
      { id: id,
        title: art.at_css('strong')&.content,
        body: art.at_css('span.num').next_element.at_css('span').content, # TODO: 改行考える
        created: art.at_css('b')&.next&.content&.yield_self do |str|
          Time.parse(str.match(%r<投稿日：(.+)\z>)[1])
        end,
        user: {
          post_number: id,
          server: server,
          username: art.at_css('b').content,
          icon_path: icon_node&.attribute('src')&.value
        } }
    )
  end

  # captcha_photo に書いてある数字を読み取って、Stringで取得するDeferredを返す
  def verify_captcha(captcha_photo)
    captcha_photo.download_pixbuf(width: 15 * 6, height: 20).next do |example|
      forecast = (example.width / 15).times.map { |i|
        deep_learning(example.subpixbuf(15 * i, 0, 15, 20))
      }.to_a.join
      if forecast.include?('?')
        dialog('投稿') {
          self[:captcha] = forecast
          label '以下の画像に表示されている数字を入力してください。'
          link captcha_photo
          input '画像認証', :captcha
        }.next do |r|
          r[:captcha]
        end
      else
        forecast
      end
    end
  end

  def deep_learning(o)
    forecasts = BIG_DATA.map { |pindex, map|
      map[point_color(o, *pindex_to_xyrgb(pindex))]
    }.inject(&:&)
    return forecasts.first if forecasts.size == 1
    '?'
  end

  def pindex_to_xyrgb(pindex)
    [pindex % (15 * 3) / 3, pindex / (15 * 3), pindex % 3]
  end

  def point_color(pb, x, y, rgb)
    pb.pixels[y * pb.rowstride + x * pb.n_channels + rgb]
  end

  # [String str_crypt, Photo captcha_photo]
  def get_regist_token(world)
    Thread.new do
      doc = URI.open("#{world.server.uri}?bbs=0", &Nokogiri::HTML.method(:parse))
      captcha_url = "#{File.dirname(world.server.uri.to_s)}/#{doc.at_css('img.capt').attribute('src').value.gsub(%r<\A./>, '')}"
      [
        doc.at_css('input[name="str_crypt"]').attribute('value').value.freeze,
        Plugin.filtering(:photo_filter, captcha_url, [])[1].first
      ].freeze
    end
  end

  def post_error_check(request, res, message=nil)
    case res
    when Net::HTTPSuccess
      doc = Nokogiri::HTML.parse(res.body)
      if doc.at_css('title').content == 'ERROR!'
        param_str = request.map { |k, v| "#{k}: #{v}" }.join("\n")
        activity :error, 'レス投稿時にエラーが発生しました', description: <<~EOM, children: message&.ancestors
          レス投稿時にエラーが発生しました。

          対称スレ: #{message&.ancestor&.perma_link || 'なし'}
          エラー:
          #{doc.at_css('#reg-area').content}

          POSTパラメータ:
          #{param_str}
        EOM
        Delayer::Deferred.fail res
      end
    else
      param_str = request.map { |k, v| "#{k}: #{v}" }.join("\n")
      activity :error, 'レス投稿時に接続エラーが発生しました', description: <<~EOM, children: message&.ancestors
        レス投稿時にエラーが発生しました。

        対称スレ: #{message&.ancestor&.perma_link || 'なし'}
        エラー: #{res.code} #{res.message}

        POSTパラメータ:
        #{param_str}
      EOM
      Delayer::Deferred.fail res
    end
    res
  end

  Delayer.new(delay: 5) { polling }
end
