# -*- coding: utf-8 -*-

module Plugin::YYBBS
  class World < Diva::Model
    register :yybbs, name: "YYBBS"

    field.string :slug, required: true
    field.uri :url, required: true

    def server
      Plugin::YYBBS::Server.new(uri: url)
    end

    def name
      url.to_s
    end

    def icon
      Skin[:post]
    end

    # def icon
    #   url = File.dirname(server.url.to_s) + '/' + icon_path.gsub(%r<\A./>, '')
    #   Plugin.filtering(:photo_filter, url, [])[1].first
    # end
  end
end
