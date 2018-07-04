# 4d-plugin-iipsrv
IIPImage server for 4D

### About

4Dで[International Image Interoperability Framework (iiif)](http://iiif.io)サーバーを構築するためのプラグインです。

[IIPImage Server](http://iipimage.sourceforge.net)がベースになっています。

* APIバージョンについて

Image APIには[1.1](http://iiif.io/api/image/1.1/)と[2.0](http://iiif.io/api/image/2.0/)があり，[iiifserver](https://github.com/klokantech/iiifserver/)は1.x，[iipsrv](https://github.com/ruven/iipsrv)は2.0をサポートしています。このプラグインは後者のコードを使用しており，両方のバージョンに対応しています。

**参考**：[IIPMooViewer](http://iipimage.sourceforge.net/documentation/iipmooviewer-2-0/)はデフォルトで2.0のAPIを使用するようになっていますが，設定で1.1に切り替えることもできます。

http://iipimage.sourceforge.net/2014/12/iiif/
