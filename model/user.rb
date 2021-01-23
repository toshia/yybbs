# -*- coding: utf-8 -*-

module Plugin::YYBBS
  class User < Diva::Model
    include Diva::Model::UserMixin

    register :yybbs_user, name: "YY-BBSユーザ"

    field.has :server, Plugin::YYBBS::Server, required: true
    field.string :username, required: true
    field.string :icon_path, required: true

    def name
      "#{username}@#{server.uri}"
    end

    def icon
      url = File.dirname(server.uri.to_s) + '/' + icon_path.gsub(%r<\A./>, '')
      Plugin.filtering(:photo_filter, url, [])[1].first
    end
  end
end
