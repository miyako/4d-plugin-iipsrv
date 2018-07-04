# 4d-plugin-iipsrv
IIPImage server for 4D

### About

4Dで[International Image Interoperability Framework (iiif)](http://iiif.io)サーバーを構築するためのプラグインです。

[IIPImage Server](http://iipimage.sourceforge.net)がベースになっています。

* APIバージョンについて

Image APIには[1.1](http://iiif.io/api/image/1.1/)と[2.0](http://iiif.io/api/image/2.0/)があり，[iiifserver](https://github.com/klokantech/iiifserver/)は1.x，[iipsrv](https://github.com/ruven/iipsrv)は2.0をサポートしています。このプラグインは後者のコードを使用しており，両方のバージョンに対応しています。

**参考**：[IIPMooViewer](http://iipimage.sourceforge.net/documentation/iipmooviewer-2-0/)はデフォルトで2.0のAPIを使用するようになっていますが，設定で1.1に切り替えることもできます。

http://iipimage.sourceforge.net/2014/12/iiif/

* 画像フォーマットについて

iiifサーバーは，**ピラミッド型タイル画像**と呼ばれる特殊な画像ファイルを処理して配信します。おもな画像形式は``TIFF``と``JPEG2000``です。ただし，拡張子が``.tif``や``jp2``であれば良いというわけではなく，中身がきちんとタイル画像になっていなければなりません。タイル型の画像は，ImageMagickなどの画像ソフトで作成することができます。 

http://iipimage.sourceforge.net/documentation/images/

* JPEG2000について

プラグインは，JPEG2000形式をサポートするために[OpenJPEG](http://www.openjpeg.org)ライブラリを使用しています。パフォーマンスは[kakadu](http://kakadusoftware.com)のほうが格段に優れているとされていますが，クローズドソース・ソフトウェアなので``disabled``設定でコンパイルしました。

* TIFFからJP2の変換について

Macのプレビューでピラミッド型TIFFをJP2形式に書き出すと，『OpenJPEGが認識できない色空間です』エラーが返されるようです。ToyViewerなどの専用アプリであれば大丈夫です。なお，OpenJPEGはプリエンプティブモード（スレッドセーフ）に対応していないので，プラグイン側で呼び出しをミューテックス管理しています。つまり，プリエンプティブモードのWebプロセスでも安全に使用することができます。

### How to

プラグインは，**かんたんモード**または**本格モード**のどちらかの方法で使用することができます。前者はデータベースに依存せず，単独で動作を確認することができるものです。後者はデータベースを画像ファイルのキャッシュサーバーとして使用することを想定したものです。

* かんたんモード

IIPImage Serverが持つ簡易キャッシュ（ハッシュテーブル）に画像が蓄えられます。
はじめに，ピラミッド型の画像ファイルが保存されているディレクトリに対するパスとキャッシュサイズを設定します。パスがWebフォルダー内にある必要はありません。キャッシュサイズはMB単位の実数です。

```
$option:=New object(\
IIP_OPT_FILESYSTEM_PREFIX;Get 4D folder(HTML Root folder);\
IIP_OPT_MAX_IMAGE_CACHE_SIZE;10000)

IIPImage SET OPTION (JSON Stringify($option))
```

あとは，``On Web Connection``に下記のコマンドを追加するだけです。

```
C_TEXT(${1})

Case of 
: ($1="/fcgi-bin/iipsrv.fcgi?@")

  C_BLOB($data)
  $data:=IIPImage Server 
  WEB SEND RAW DATA($data)
  
 End case 
```

**注記**: URL（上記の例では``/fcgi-bin/iipsrv.fcgi?``）はクライアント側，つまりビューアソフトに依存します。

プラグインは内部的に``WEB GET HTTP HEADER``をコールして``X-URL``から``QUERY_STRING``を取り出し，リクエストの内容に応じた画像（JPEG）・JSON・XML・HTML・テキスト（エラーメッセージなど）を返します。画像ファイルはイメージキャッシュ（ファイル名と日付の管理）とタイルキャッシュ（再利用できるタイル画像）に追加されてゆきます。

* 本格モード

かんたんモードと同じように，ピラミッド型の画像ファイルが保存されているディレクトリに対するパスを指定します。データベースでタイル画像を管理するので，キャッシュサイズは0で構いません。

```
$option:=New object(\
IIP_OPT_FILESYSTEM_PREFIX;Get 4D folder(HTML Root folder);\
IIP_OPT_MAX_IMAGE_CACHE_SIZE;0)

IIPImage SET OPTION (JSON Stringify($option))
```

``On Web Connection``は，いくつかのステップにわけてコードを記述することになります。

はじめに，受信したリクエストに対応するキーをプラグインに計算させます。

```
C_TEXT(${1})

Case of 
: ($1="/fcgi-bin/iipsrv.fcgi?@")

  C_TEXT($key)
  $key:=IIPImage Get key 
  
 End case 
```

キーは，タイル画像を特定するためのIDみたいなものです。タイル画像をキャッシュから返すことになるiiifコマンドは``FIF``, ``IIIF``など，いくつか存在しますが，最終的には``CVT``または``JTL``の処理にリダイレクトされるため，キーは下記いずれかのパターンとなります。

``JTL:resolution:tile:xangle:yangle:layers:compression``

または

``CVT:resolution:xangle:yangle:layers:left:top:width:height``

キーに空が文字が返されるのは，画像以外のレスポンスが予期される場合です。そのまま，かんたんモードで処理を終えてください。

```
If ($key="")
  $data:=IIPImage Server 
  WEB SEND RAW DATA($data)
End if
```
