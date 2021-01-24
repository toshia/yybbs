# -*- coding: utf-8 -*-

module Plugin::YYBBS
  class Message < Diva::Model
    include Diva::Model::MessageMixin

    register :yybbs_message, name: 'YY-BBS記事'

    field.int :id, required: true
    field.has :user, Plugin::YYBBS::User, required: true
    field.has :thread, Plugin::YYBBS::Message, required: false
    field.string :title, required: true
    field.string :body, required: true
    field.time :created, required: true

    def description
      "#{title}\n#{body}"
    end

    def server
      user.server
    end

    def perma_link
      Diva::URI(server.uri.to_s + "?res=#{id}&bbs=1&pg=0")
    end

    def repliable?
      true
    end

    def has_receive_message?
      !!thread
    end

    def replyto_source_d(force=false)
      Delayer::Deferred.new do
        thread
      end
    end

    def ancestor
      thread || self
    end

    def ancestors
      [self, thread].compact
    end
  end
end
