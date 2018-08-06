/* --------------------------------------------------------------------------------
 #
 #	4DPlugin.h
 #	source generated by 4D Plugin Wizard
 #	Project : iipsrv
 #	author : miyako
 #	2018/06/29
 #
 # --------------------------------------------------------------------------------*/

// --- iipsrv
void IIPImage_Server(sLONG_PTR *pResult, PackagePtr pParams, bool key_only = false, bool image_only = false);
void IIPImage_Get_cache_info(sLONG_PTR *pResult, PackagePtr pParams);

// --- Time
void Convert_time_rfc_to_iso(sLONG_PTR *pResult, PackagePtr pParams);

// --- iipsrv
void IIPImage_SET_OPTION(sLONG_PTR *pResult, PackagePtr pParams);
void IIPImage_Get_option(sLONG_PTR *pResult, PackagePtr pParams);

void syncEnv();

void startCache();
void clearCache();
void initURIMap();

void initClock();
void resetClock();

#define CMU_WEB_SEND_RAW_DATA 815
#define CMU_WEB_GET_HTTP_HEADER 697
#define CMU_EXECUTE_METHOD 1007

#include <mutex>
#include <locale> /* toupper */
#include <fcgiapp.h>

#include <ctime>
#include <csignal>
#include <iostream>
#include <fstream>
#include <string>
#include <utility>
#include <map>
#include <algorithm>

#include "TPTImage.h"
#include "JPEGCompressor.h"
#include "OpenJPEGImage.h"
#include "Tokenizer.h"
#include "IIPResponse.h"
#include "View.h"
#include "Timer.h"
#include "TileManager.h"
#include "Task.h"
#include "Environment.h"
#include "Writer.h"

#include "libjson.h"
#include "libjson_methods.h"

#ifdef HAVE_MEMCACHED
#ifdef WIN32
#include "../windows/MemcachedWindows.h"
#else
#include "Memcached.h"
#endif
#endif

#ifdef ENABLE_DL
#include "DSOImage.h"
#endif

#ifdef _OPENMP
#include <omp.h>
#endif
