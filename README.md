Sorry this plugin is Japanese only.

# なにこれ

[YY\-BOARD : KENT\-WEB CGI/Perl フリーソフト](https://www.kent-web.com/bbs/yybbs.html) にて公開されているYY-BOARDの閲覧・投稿をmikutter上で行えるようにするプラグインです

現在、以下のことができます。

- **World対応** 複数のBBSをアカウントに見立てて登録できます。これで相互リンク先のBBSを全部mikutterで見れます！
- **yybbsタブ** スレ・レスをmikutter上で単一のTLで表示します（今後もっといろんな表示に対応するかも）
- **スレッド機能** 「会話スレッドを表示」に対応しており、そのレスに対応するスレを表示できます
- **投稿**

# 動作条件

- Ruby 2.6以降
- mikutter 4.1以降

# インストール方法

```
mkdir -p ~/.mikutter/plugin/; git clone https://github.com/toshia/yybbs.git ~/.mikutter/plugin/yybbs/
```

# 使い方

## World

インストールしたあとは、mikutter左上の、Mastodonなど他のアカウントのアイコンが表示されているのをクリックすると、「Worldを追加」というメニューが出てきます。

次の画面でYYBBSを選択し、画面の指示に従って追加してください。World登録時点でHNなどを設定することになります。

## 投稿

本文の入力はMastodonと同じようにできますが、以下の制約があります。

- スレを立てる時は、画面一番上のpostboxに入力して投稿します。ただしこの場合、1行目はタイトル、2行目以降が本文です。1行目はタイトルなので15文字以内になるようにしてください。
- スレやレスへのリプライを行うと、レスを投稿できます。レスのタイトルは「Re: （スレタイ）」固定です。1行目から本文になります。また、タイトルが15文字を超えたら適当にちょん切られます
- ディープラーニング機能により、AIでcaptchaを自動的に突破する機能が搭載されています。AIによる判断ができなかった場合、投稿直後にcaptchaが出てきます。

# テクニック

## 自作自演に便利！

複数の掲示板をWorldとして登録できますが、別々のWorldが同じ掲示板を指していても構いません。

なんの役に立つかと言うと、HNなどはWorld作成時に指定するので、Worldの切り替えでそれらの情報を切り替えられるということです。

スレでの自作自演など、複数の名義を使い分けたいときに便利です。

# リンク集

- **[d250g2掲示板](https://d250g2.com/yybbs/yybbs.cgi)** :: いつもお世話になってます！掲示板が賑わっていて、とっても楽しいホームページです！

# 相互リンクについて

当ホームページにリンクを貼るときは、以下の画像をダウンロードして使ってください。

<img src="https://github.com/toshia/yybbs/raw/gazou/link-banner00-200x40.png" />

```html
<a href="https://github.com/toshia/yybbs/"><img src="https://github.com/toshia/yybbs/raw/gazou/link-banner00-200x40.png" /></a>
```

<img src="https://github.com/toshia/yybbs/raw/gazou/link-banner00-88x31.png" />

```html
<a href="https://github.com/toshia/yybbs/"><img src="https://github.com/toshia/yybbs/raw/gazou/link-banner00-88x31.png" /></a>
```
