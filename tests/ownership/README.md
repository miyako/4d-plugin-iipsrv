# Ownership regressions

`engine_harness.mm` links the real `4DPlugin.cpp`, the `iipsrv/*.cc` sources, `libjson_methods.cpp`, the plugin classes and the unchanged bundled `4D Plugin API` with ASan/UBSan. It replaces the 4D engine (`Call4D`) with a synthetic one. That engine counts live engine strings, handles and reference-counted pictures, and aborts on anything it does not model.

The third-party static libraries (libtiff, libjpeg, openjpeg, libjson) are not in the repository. `run.sh` replaces their C entry points with generated stubs that abort if called; no test reaches them. `IIPImage Server`, `Get key` and `Get image` run through `PluginMain` with synthetic `WEB GET HTTP HEADER` arrays and `LOGFILE=/dev/null`.

```sh
tests/ownership/run.sh . fixed                # every test must pass

B=$(mktemp -d); git archive <base-sha> | tar -x -C "$B"
tests/ownership/run.sh "$B" baseline          # named defects must fail, controls pass
```

| Test | Checks |
|---|---|
| `defect_picture_fromfile_ownership` | `C_PICTURE::fromFileAtPath` frees the path once and releases the loaded picture |
| `defect_picture_setbytes_leak` | `C_PICTURE::setBytes` releases the picture it creates |
| `defect_picture_createcopy_ownership` | `createCopy*` reads only the converted type (byte size, not characters) and leaves no empty owners |
| `defect_picture_grayscale_owner_leak`, `defect_picture_getsize_owner_leak`, `defect_picture_thumbnail_owner_leak` | no empty picture owner leaks |
| `control_server_*`, `control_get_*` | header arrays are read borrowed and released, across repeated calls and text/blob returns |
| `control_array_text_transfer`, `control_picture_param_return` | `ARRAY_TEXT` transfer, picture parameter/return |

`C_PICTURE` is compiled into the plugin, but no command calls it.

Not covered:
- Windows and a real 4D runtime.
- Image decoding/encoding (third-party libraries are stubbed).
- How the real engine treats the old value of a picture output parameter. The harness assumes the most forgiving model: the engine releases it.
