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

空ではない文字列が返された場合，データベースをクエリして，そのキーに対応する画像がないか，探します。再利用できる画像があれば，そのまま``WEB SEND BLOB``で返して終了です。

```
ARRAY TEXT($names;2)
ARRAY TEXT($values;2)

$names{1}:="Last-Modified"
$names{2}:="Cache-Control"
$values{1}:=String(Current date;Date RFC 1123;Current time)
$values{2}:="max-age=86400"

QUERY([IMAGES];[IMAGES]key=$key)

If (Is record loaded([IMAGES]))
					
  C_BLOB($data)
  PICTURE TO BLOB([IMAGES]data;$data;"image/jpeg")
  WEB SEND BLOB($data;"image/jpeg")

End if
```

再利用できる画像がなければ，改めてプラグインをコールし，返された画像をデータベースに保存すると同時にレスポンスを返して終了です。

```
C_BLOB($data)
$data:=IIPImage Get image 
CREATE RECORD([IMAGES])
[IMAGES]key:=$key
BLOB TO PICTURE($data;[IMAGES]data;"image/jpeg")
SAVE RECORD([IMAGES])
WEB SEND BLOB($data;"image/jpeg")
```

### Examples

データベースを起動すると，ローカルホストでWebサーバーを起動し，``http://127.0.0.1/gallery.html```ページが開かれます。

1番と3番の画像はTIFF，2番はJPEG2000です。

タイル画像：http://digitalnagasaki.hatenablog.com/entry/2016/04/21/214423

<img src="https://user-images.githubusercontent.com/1725068/42255231-ac8e6728-7f85-11e8-9734-78d749a2d7ec.png" width="600"/>

ページ表示と同時にレコードがデータベースに追加されていることに注目できます。

<img width="600" alt="2018-07-04 12 30 28" src="https://user-images.githubusercontent.com/1725068/42255341-3056ed3c-7f86-11e8-8ef0-1896bfa4a5a5.png">

ビューア上で画像をズームしたり，動かしたりしてみてください。

動的にタイル画像が生成され，ブラウザに表示されてゆきます。

<img width="600" src="https://user-images.githubusercontent.com/1725068/42255391-6dd08c18-7f86-11e8-85a3-907e04d16813.png" />

作成してタイル画像は，データベースのピクチャフィールドに保存されてゆくので，二度目以降は表示が速くなります。特にJPEG2000はTIFFよりも処理に時間がかかるので，その差が顕著です。なお，データベースに保存されたタイル画像は，``DEBUG``メソッドで確認することができます。

