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

Macのプレビューでピラミッド型TIFFをJP2形式に書き出すと，『OpenJPEGが認識できない色空間です』エラーが返されるようです。ToyViewerなどの専用アプリであれば大丈夫です。なお，OpenJPEGはプリエンプティブモード（スレッドセーフ）に対応していないので，プラグイン側で呼び出しをミューテックス管理しています。つまり，プリエンプティブモードのWEbプロセスでも安全に使用することができます。
