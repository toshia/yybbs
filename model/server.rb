# frozen_string_literal: true

module Plugin::YYBBS
  class Server < Diva::Model
    register :yybbs_server, name: "YYBBSサーバ"

    field.uri :uri, required: true

    def title
      url.to_s
    end

    def perma_link
      uri
    end
  end
end
