# 4d-plugin-iipsrv

An [IIPImage](https://iipimage.sourceforge.io) image server inside the 4D Web server. The plugin embeds the [iipsrv](https://github.com/ruven/iipsrv) request engine: from `On Web Connection` it reads the current request's URL, runs the IIP, [IIIF Image API](https://iiif.io/api/image/) (1.1 and 2.0), Zoomify or DeepZoom command it contains, and returns the HTTP response as a `Blob` (JPEG tiles, `info.json`, XML, or an error page) that you send with `WEB SEND RAW DATA`. Source images are pyramidal tiled TIFF (libtiff) and JPEG 2000 (OpenJPEG). Tiles are always JPEG-encoded.

| Command | Returns | Purpose |
|---|---|---|
| [IIPImage Server](#iipimage-server) | `Blob` | Handle the current web request and return the full raw HTTP response |
| [IIPImage Get key](#iipimage-get-key) | `Text` | Return the cache key of the tile or region the request asks for, without decoding it |
| [IIPImage Get image](#iipimage-get-image) | `Blob` | Return only the JPEG bytes of the requested tile or region (no HTTP header) |
| [IIPImage SET OPTION](#iipimage-set-option) | — | Set server options (image folder, cache size, JPEG quality, CORS, …) |
| [IIPImage Get option](#iipimage-get-option) | `Text` | Return the current options as JSON |
| [IIPImage Get cache info](#iipimage-get-cache-info) | `Text` | Return the state of the in-memory tile and image caches as JSON |
| [Convert time rfc to iso](#convert-time-rfc-to-iso) | `Text` | Convert an RFC 1123 HTTP date to an ISO 8601 `…Z` string |

**Platforms:** macOS, Windows (x64). See [Releases](https://github.com/miyako/4d-plugin-iipsrv/releases).

---

## Requirements & platform notes

- **Call the request commands from `On Web Connection`.** [IIPImage Server](#iipimage-server), [IIPImage Get key](#iipimage-get-key) and [IIPImage Get image](#iipimage-get-image) take no URL: they call `WEB GET HTTP HEADER` themselves and read the request URL from the `X-URL` header. Outside a web process there is no URL, and you get the iipsrv home page (a `400 Bad Request` page) back.
- **Images must be tiled pyramids.** A `.tif` or `.jp2` extension is not enough: the file has to be a multi-resolution tiled TIFF or a JPEG 2000 file. ImageMagick, libvips and similar tools can write them. See [IIPImage: image formats](https://iipimage.sourceforge.io/documentation/images).
- **JPEG 2000 is decoded by OpenJPEG, one image at a time.** OpenJPEG is not used concurrently: every JPEG 2000 open and decode in the whole 4D process goes through one lock. Kakadu is not compiled in. Prefer tiled TIFF for large collections, or store generated tiles in your database (see [IIPImage Get key](#iipimage-get-key)).
- **Not supported:** PNG output (`PTL`), memcached (the `LIBMEMCACHED_*` options are accepted and ignored).
- **Options are process-wide.** [IIPImage SET OPTION](#iipimage-set-option) stores its values in the environment variables of the 4D process (that is how iipsrv reads its configuration), so one call applies to every process. Call it once at startup, for example in `On Startup`, before the Web server accepts requests.
- **The plugin sets the `TZ` environment variable of the whole 4D process to UTC when it loads**, and restores it when 4D quits (iipsrv does this for its HTTP dates). Anything in the same process that formats local time through the C library (other plugins, and possibly 4D itself) sees UTC while the plugin is loaded.
- **The commands are declared thread-safe** and can be called from preemptive web processes. Read the concurrency note under [Error handling & troubleshooting](#error-handling--troubleshooting) first.

---

## IIPImage Server

### Syntax

```
response := IIPImage Server ( unused )
```

| Parameter | Type | Description |
|---|---|---|
| `unused` | Longint | **Ignored.** Declared by the plugin but never read. The project's own examples call the command without it |
| Result | Blob | The complete HTTP response: header lines, an empty line, then the body |

### Description

`IIPImage Server` gets the current request's headers with `WEB GET HTTP HEADER`, takes the URL from `X-URL`, and runs the request:

- With no `URI_MAP` option, everything after the `?` is the command list: `name=value` pairs separated by `&`, e.g. `?FIF=0001.tif&WID=400&CVT=jpeg` or `?IIIF=0001.tif/full/full/0/default.jpg`. Command names are case-insensitive.
- With `URI_MAP` set to `prefix=>protocol` (`iip`, `iiif`, `zoomify` or `deepzoom`), a URL that starts with `/prefix/` is mapped to that protocol and its query string is dropped. See [IIPImage SET OPTION](#iipimage-set-option).

The image name in `FIF`/`IIIF` is appended to the `FILESYSTEM_PREFIX` option to build the file path. Any `../` is removed from it first.

The response starts with CGI-style header lines (`Status: …`, `Server: iipsrv/…`, `Content-Type: …`, `Last-Modified: …`, `Cache-Control: …`), then an empty line, then the body. The plugin's examples pass it unchanged to `WEB SEND RAW DATA`.

Opened images are kept in an image cache (file name and modification date) and encoded tiles in a tile cache, both in memory; the tile cache is limited by the `MAX_IMAGE_CACHE_SIZE` option. A request whose `If-Modified-Since` header matches the cached image gets `Status: 304 Not Modified` with no body.

Failures are returned as responses, never as 4D errors:

| Situation | Response |
|---|---|
| No query string, or a request iipsrv can't parse | iipsrv home page, `Status: 400 Bad Request` |
| Image file not found or unreadable | `Status: 404 Not Found` and the reason as text |
| Invalid parameter value | `Status: 400 Bad Request` and the reason as text |
| Unknown command, or a command with nothing to send | IIP error response (`Status: 400 Bad Request`) |
| Unexpected internal failure | Empty `Blob` (since the 1.0.0 code review; before, the call could leave 4D waiting for a result) |

### Example

From the plugin's previous README (simple mode, the plugin's memory caches only):

```4d
$option:=New object(\
IIP_OPT_FILESYSTEM_PREFIX;Get 4D folder(HTML Root folder);\
IIP_OPT_MAX_IMAGE_CACHE_SIZE;10000)

IIPImage SET OPTION (JSON Stringify($option))
```

```4d
C_TEXT(${1})

Case of 
: ($1="/fcgi-bin/iipsrv.fcgi?@")

  C_BLOB($data)
  $data:=IIPImage Server 
  WEB SEND RAW DATA($data)
  
 End case 
```

The URL prefix (`/fcgi-bin/iipsrv.fcgi?` here) is whatever your viewer sends; configure it in the viewer.

---

## IIPImage Get key

### Syntax

```
key := IIPImage Get key ( unused )
```

| Parameter | Type | Description |
|---|---|---|
| `unused` | Longint | **Ignored.** Declared but never read |
| Result | Text | Cache key of the requested tile or region, or `""` |

### Description

Runs the request like [IIPImage Server](#iipimage-server) (it opens the image and reads its metadata), but stops before any tile is decoded or encoded, and returns a key that identifies the image the request would produce. Use it to keep generated tiles in your own table and skip the decoding next time.

Tile requests (`JTL`, and IIIF requests for exactly one tile) give

```
JTL:<image path>:<resolution>:<tile>:<horizontal angle>:<vertical angle>:<compression>:<quality>
```

Region requests (`CVT`, and other IIIF image requests) give

```
CVT:<image path>:<resolution>:<horizontal angle>:<vertical angle>:<layers>:<left>:<top>:<width>:<height>
```

`<image path>` is the full file path, prefix included.

The key is `""` when the request does not produce an image (`info.json`, `OBJ`, errors). Handle those with [IIPImage Server](#iipimage-server).

**The key does not contain every request parameter.** A `CVT` key has no JPEG quality, rotation, colour or output-size parameters beyond the region, and neither key changes when the source file changes. Requests that differ only in those parameters share a key (inferred from the key fields above). If your viewer sends such parameters, add them to your own key or don't cache those requests, and clear your stored tiles when you replace a source file.

### Example

From the plugin's previous README (database mode). The plugin's own cache is set to 0 because the database is the cache:

```4d
$option:=New object(\
IIP_OPT_FILESYSTEM_PREFIX;Get 4D folder(HTML Root folder);\
IIP_OPT_MAX_IMAGE_CACHE_SIZE;0)

IIPImage SET OPTION (JSON Stringify($option))
```

```4d
C_TEXT(${1})

Case of 
: ($1="/fcgi-bin/iipsrv.fcgi?@")

  C_TEXT($key)
  $key:=IIPImage Get key 
  
 End case 
```

```4d
If ($key="")
  $data:=IIPImage Server 
  WEB SEND RAW DATA($data)
End if
```

```4d
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

The flow continues with [IIPImage Get image](#iipimage-get-image).

---

## IIPImage Get image

### Syntax

```
jpeg := IIPImage Get image ( unused )
```

| Parameter | Type | Description |
|---|---|---|
| `unused` | Longint | **Ignored.** Declared but never read |
| Result | Blob | JPEG data of the requested tile or region, without HTTP header lines |

### Description

Runs the request like [IIPImage Server](#iipimage-server), but for tile and region requests it leaves out the HTTP header lines, so the result is a plain JPEG you can store in a picture field or send with `WEB SEND BLOB`.

For requests that are not tile or region requests (`info.json`, errors), the result is the same full response as [IIPImage Server](#iipimage-server), header lines included. Call it only after [IIPImage Get key](#iipimage-get-key) returned a non-empty key.

The tile also goes into the plugin's tile cache, unless `MAX_IMAGE_CACHE_SIZE` is 0.

### Example

From the plugin's previous README, the last step of the database mode:

```4d
C_BLOB($data)
$data:=IIPImage Get image 
CREATE RECORD([IMAGES])
[IMAGES]key:=$key
BLOB TO PICTURE($data;[IMAGES]data;"image/jpeg")
SAVE RECORD([IMAGES])
WEB SEND BLOB($data;"image/jpeg")
```

---

## IIPImage SET OPTION

### Syntax

```
IIPImage SET OPTION ( options )
```

| Parameter | Type | Description |
|---|---|---|
| `options` | Text | A JSON object. Each property sets one option (see the table below) |

### Description

Use the `IIP_OPT_*` constants (theme "IIP options") as property names: their values are the option names below (`IIP_OPT_JPEG_QUALITY` = `"JPEG_QUALITY"`). Properties you leave out keep their current value. Unknown properties, and text that isn't a JSON object, are ignored without an error.

Property names are case-sensitive and matched by prefix: `"CORS_x"` also sets `CORS`.

| Option | Kind | Default | Effect |
|---|---|---|---|
| `FILESYSTEM_PREFIX` | folder path | `""` | Prepended to the image name of every request. A trailing separator is added |
| `FILENAME_PATTERN` | text | `"_pyr_"` | Pattern for multi-file image sequences |
| `MAX_IMAGE_CACHE_SIZE` | real (MB) | `10` | Size of the in-memory tile cache. **Setting it clears both caches** |
| `JPEG_QUALITY` | integer | `75` | JPEG quality, clamped to 1–100 |
| `MAX_CVT` | integer (pixels) | `5000` | Largest region a `CVT` request may produce (minimum 64) |
| `MAX_LAYERS` | integer | `0` | Maximum JPEG 2000 quality layers to decode (0 = all) |
| `INTERPOLATION` | integer | `1` | Resampling: 0 nearest neighbour, 1 bilinear |
| `ALLOW_UPSCALING` | 0 or 1 | `1` | Allow output larger than the source image |
| `EMBED_ICC` | 0 or 1 | `1` | Embed the image's ICC profile in the JPEG output |
| `CORS` | text | `""` | Sent as `Access-Control-Allow-Origin: <value>` (e.g. `"*"`) |
| `CACHE_CONTROL` | text | `"max-age=86400"` | Value of the `Cache-Control` header |
| `BASE_URL` | text | `""` | Base URL to use in responses such as IIIF `info.json` |
| `URI_MAP` | text | `""` | `"prefix=>protocol"`, protocol one of `iip`, `iiif`, `zoomify`, `deepzoom` |
| `WATERMARK` | file path | `""` | TIFF image applied as a watermark |
| `WATERMARK_PROBABILITY` | real | `1` | Fraction of tiles that get the watermark, 0–1 |
| `WATERMARK_OPACITY` | real | `1` | Watermark opacity, 0–1 |
| `VERBOSITY` | integer | `1` | Log level (0 = no log; higher = more detail) |
| `LOGFILE` | file path | `"/tmp/iipsrv.log"` | Log file, opened for each request |
| `LIBMEMCACHED_SERVERS`, `LIBMEMCACHED_TIMEOUT` | — | — | **Ignored**: memcached is not compiled in |

For the meaning of each option in detail, see [the iipsrv documentation](https://iipimage.sourceforge.io/documentation/server/).

Pass paths in the system format. **On macOS** `FILESYSTEM_PREFIX`, `WATERMARK` and `LOGFILE` are read as HFS paths (`Macintosh HD:Users:…`, as `Get 4D folder` returns them) and converted to POSIX. **On Windows** backslashes become forward slashes.

**Keep `FILESYSTEM_PREFIX` set.** The image name from the URL is appended to it as is; `../` is removed, but nothing else is checked. With the default empty prefix, a request can name any TIFF or JPEG 2000 file that 4D can read.

Values are converted to the option's type with the C library (`atoi`/`atof`), so `"75"` and `75` both work. A JSON boolean for `ALLOW_UPSCALING`/`EMBED_ICC` is converted by libjson (inferred, not tested); pass `0` or `1` to be sure.

### Example

From the plugin's previous README:

```4d
$option:=New object(\
IIP_OPT_FILESYSTEM_PREFIX;Get 4D folder(HTML Root folder);\
IIP_OPT_MAX_IMAGE_CACHE_SIZE;10000)

IIPImage SET OPTION (JSON Stringify($option))
```

Allowing any origin and lowering the JPEG quality:

```4d
$option:=New object(\
IIP_OPT_CORS;"*";\
IIP_OPT_JPEG_QUALITY;60)

IIPImage SET OPTION (JSON Stringify($option))
```

---

## IIPImage Get option

### Syntax

```
options := IIPImage Get option
```

| Parameter | Type | Description |
|---|---|---|
| Result | Text | JSON object of all options |

### Description

Returns every option of [IIPImage SET OPTION](#iipimage-set-option) with the value iipsrv actually uses (defaults filled in, values clamped): `VERBOSITY`, `LOGFILE`, `MAX_IMAGE_CACHE_SIZE`, `FILENAME_PATTERN`, `JPEG_QUALITY`, `MAX_CVT`, `MAX_LAYERS`, `FILESYSTEM_PREFIX`, `WATERMARK`, `WATERMARK_PROBABILITY`, `WATERMARK_OPACITY`, `LIBMEMCACHED_SERVERS`, `LIBMEMCACHED_TIMEOUT`, `INTERPOLATION`, `CORS`, `BASE_URL`, `CACHE_CONTROL`, `ALLOW_UPSCALING` (boolean), `URI_MAP`, `EMBED_ICC` (boolean). On macOS, paths come back in POSIX form.

### Example

```4d
C_OBJECT($option)
$option:=JSON Parse(IIPImage Get option)
ALERT($option.FILESYSTEM_PREFIX)
```

---

## IIPImage Get cache info

### Syntax

```
info := IIPImage Get cache info
```

| Parameter | Type | Description |
|---|---|---|
| Result | Text | JSON object describing the caches |

### Description

| Property | Type | Description |
|---|---|---|
| `count` | Number | Number of tiles in the tile cache |
| `size` | Number | Memory used by the tile cache, in MB |
| `maxSize` | Number | Tile cache limit, in MB (`MAX_IMAGE_CACHE_SIZE`, rounded down) |
| `tileSize` | Number | Bookkeeping overhead iipsrv counts per cached tile, in bytes |
| `files` | Collection | One object per cached image: `key` (the image name as requested) and `timestamp` (the file's modification date as an HTTP date, GMT) |

If another process cleared the caches with [IIPImage SET OPTION](#iipimage-set-option) at that moment, the tile properties are missing and `files` is empty (since the 1.0.0 code review; before, the call could crash).

### Example

```4d
C_OBJECT($info)
$info:=JSON Parse(IIPImage Get cache info)
ALERT(String($info.count)+" tiles, "+String($info.files.length)+" images")
```

---

## Convert time rfc to iso

### Syntax

```
iso := Convert time rfc to iso ( rfc )
```

| Parameter | Type | Description |
|---|---|---|
| `rfc` | Text | Date in HTTP (RFC 1123) format, e.g. `"Wed, 04 Jul 2018 03:30:28 GMT"` |
| Result | Text | The same date and time as `"2018-07-04T03:30:28Z"`, or `""` |

### Description

Parses `rfc` with the pattern `%a, %d %b %Y %H:%M:%S %Z` and writes the date and time fields back as `YYYY-MM-DDTHH:MM:SSZ`. There is no time-zone conversion: the fields are copied unchanged and `Z` is appended, which is right for HTTP dates (always GMT). Text that doesn't match the pattern gives `""`. **On Windows** the parsing uses the `strptime` replacement bundled with iipsrv; its handling of `%a` and `%Z` has not been verified.

Useful with the `Last-Modified` header of a response, or the `timestamp` values of [IIPImage Get cache info](#iipimage-get-cache-info).

### Example

```4d
$iso:=Convert time rfc to iso("Wed, 04 Jul 2018 03:30:28 GMT")
// $iso = "2018-07-04T03:30:28Z"
```

---

## Example database

`iipsrv.4dbase` starts the Web server on localhost and opens `http://127.0.0.1/gallery.html`, an IIPMooViewer gallery of the images in `WebFolder` (images 1 and 3 are TIFF, 2 is JPEG 2000; tiled images from [digitalnagasaki](http://digitalnagasaki.hatenablog.com/entry/2016/04/21/214423)). It uses the database mode: tiles are stored in the `[IMAGES]` table as they are generated, so the second view is faster, especially for JPEG 2000.

<img src="https://user-images.githubusercontent.com/1725068/42255231-ac8e6728-7f85-11e8-9734-78d749a2d7ec.png" width="600"/>

<img width="600" alt="records" src="https://user-images.githubusercontent.com/1725068/42255341-3056ed3c-7f86-11e8-8ef0-1896bfa4a5a5.png">

<img width="600" alt="tiles" src="https://user-images.githubusercontent.com/1725068/42255391-6dd08c18-7f86-11e8-85a3-907e04d16813.png" />

<img width="600" alt="stored tiles" src="https://user-images.githubusercontent.com/1725068/42255487-fb907446-7f86-11e8-8ca3-947d1ac619c9.png">

---

## Error handling & troubleshooting

- **Nothing raises a 4D error.** Request problems come back as HTTP responses (`400`, `404`, the iipsrv home page), and bad options are ignored. Check the response, or set `VERBOSITY` to 3 or more and read `LOGFILE`.
- **You always get the iipsrv home page.** There is no query string: the command was called outside `On Web Connection`, or the viewer's URL has no `?…` part and no `URI_MAP` matches it.
- **`404 Not Found` for an image that exists.** The path is `FILESYSTEM_PREFIX` + the name in the URL. On macOS, pass the prefix as an HFS path (as `Get 4D folder` returns it): a POSIX path is converted as if it were HFS. Check the value with [IIPImage Get option](#iipimage-get-option).
- **A `.tif`/`.jp2` file fails to open or looks wrong.** It must be a tiled, multi-resolution file. JPEG 2000 files exported by macOS Preview can be rejected by OpenJPEG with an unsupported colour space error.
- **JPEG 2000 is slow.** Decoding is serialized across the whole process. Keep generated tiles in the database ([IIPImage Get key](#iipimage-get-key)) or convert the sources to tiled TIFF.
- **Changing `MAX_IMAGE_CACHE_SIZE` empties the caches.** Set it once at startup.
- **Stale tiles from your own table.** Keys don't change when a source file changes, and `CVT` keys leave out quality, rotation and colour parameters. See [IIPImage Get key](#iipimage-get-key).
- **Local times look like UTC in other code.** The plugin sets `TZ` to UTC for the 4D process while it is loaded. See [Requirements & platform notes](#requirements--platform-notes).
- **Known issue: concurrent preemptive requests.** The 1.0.0 code review found that the shared tile cache is read and written without a lock, and that [IIPImage SET OPTION](#iipimage-set-option) can delete the caches while a request still uses them. Until this is fixed, many simultaneous requests from preemptive web processes, or changing `MAX_IMAGE_CACHE_SIZE` while the server is busy, can crash 4D.
- **Known issue (Windows):** in 1.0.0 the text options (`FILESYSTEM_PREFIX`, `CORS`, `URI_MAP`, `BASE_URL`, …) are read from the wrong environment variable on Windows, so setting them has no effect there. Found in the 1.0.0 code review, not fixed yet.

---

## Quick reference

```4d
// On Startup
IIPImage SET OPTION (JSON Stringify(New object(\
IIP_OPT_FILESYSTEM_PREFIX;Get 4D folder(HTML Root folder);\
IIP_OPT_MAX_IMAGE_CACHE_SIZE;0)))

// On Web Connection
C_TEXT($key)
C_BLOB($data)
$key:=IIPImage Get key 
If ($key="")
	$data:=IIPImage Server 
	WEB SEND RAW DATA($data)
Else 
	QUERY([IMAGES];[IMAGES]key=$key)
	If (Is record loaded([IMAGES]))
		PICTURE TO BLOB([IMAGES]data;$data;"image/jpeg")
	Else 
		$data:=IIPImage Get image 
		CREATE RECORD([IMAGES])
		[IMAGES]key:=$key
		BLOB TO PICTURE($data;[IMAGES]data;"image/jpeg")
		SAVE RECORD([IMAGES])
	End if 
	WEB SEND BLOB($data;"image/jpeg")
End if 

// Diagnostics
$options:=JSON Parse(IIPImage Get option)
$cache:=JSON Parse(IIPImage Get cache info)
```

## Building from source

The macOS static libraries are not committed. Build them once before opening the Xcode project:

```bash
scripts/build-macos-deps.sh
```

This downloads pinned, checksummed releases of libjpeg 9c, libtiff 4.0.9, OpenJPEG 2.3.0 and libjson 7.6.1, which match the headers in `include/`. It builds each one universal (arm64 + x86_64, macOS 11.5) into `a/`. zlib comes from the macOS SDK. You need the Xcode command line tools and `cmake`. The release workflow runs the same script and caches the result.

The Windows build still links the prebuilt libraries in `lib/x64`.

## Credits

Based on [iipsrv](https://github.com/ruven/iipsrv) by Ruven Pillay (GPL v3), with libtiff, OpenJPEG, libjpeg, zlib and libjson.
