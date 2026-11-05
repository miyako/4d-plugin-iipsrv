/*
    IIP Environment Variable Class

    Copyright (C) 2006-2017 Ruven Pillay.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software Foundation,
    Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#ifndef _ENVIRONMENT_H
#define _ENVIRONMENT_H


/* Define some default values
 */
#define VERBOSITY 1
#define LOGFILE "/tmp/iipsrv.log"
#define MAX_IMAGE_CACHE_SIZE 10.0
#define FILENAME_PATTERN "_pyr_"
#define JPEG_QUALITY 75
#define MAX_CVT 5000
#define MAX_LAYERS 0
#define FILESYSTEM_PREFIX ""
#define WATERMARK ""
#define WATERMARK_PROBABILITY 1.0
#define WATERMARK_OPACITY 1.0
#define LIBMEMCACHED_SERVERS "localhost"
#define LIBMEMCACHED_TIMEOUT 86400  // 24 hours
#define INTERPOLATION 1  // 1: Bilinear
#define CORS ""
#define BASE_URL ""
#define CACHE_CONTROL "max-age=86400" // 24 hours
#define ALLOW_UPSCALING true
#define URI_MAP ""
#define EMBED_ICC true


#include <string>


/// Class to obtain environment variables

class Environment {


 public:

#if _WIN32
	static std::string getEnvUTF8(const wchar_t *env, const char *fallback){
		wchar_t *envpara = _wgetenv(L"LOGFILE");
		if(envpara)
		{
			size_t size = wcslen(envpara);
			int len = WideCharToMultiByte(CP_UTF8, 0, envpara, size, NULL, 0, NULL, NULL);
			if(len)
			{
				std::vector<uint8_t> buf(len + 1);
				if(WideCharToMultiByte(CP_UTF8, 0, envpara,size, (LPSTR)&buf[0], len, NULL, NULL))
				{
					return std::string((const char *)&buf[0]);
				}
			}
		}
		return fallback;
	}
#endif
	
  static int getVerbosity(){
    int loglevel = VERBOSITY;
    char *envpara = getenv( "VERBOSITY" );
    if( envpara ){
      loglevel = atoi( envpara );
      // If not a realistic level, set to zero
      if( loglevel < 0 ) loglevel = 0;
    }
    return loglevel;
  }

  static std::string getLogFile(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"LOGFILE", LOGFILE);
#else
		char* envpara = getenv( "LOGFILE" );
		if( envpara ) return std::string(envpara);
#endif
		return LOGFILE;
  }


  static float getMaxImageCacheSize(){
    float max_image_cache_size = MAX_IMAGE_CACHE_SIZE;
    char* envpara = getenv( "MAX_IMAGE_CACHE_SIZE" );
    if( envpara ){
      max_image_cache_size = atof( envpara );
    }
    return max_image_cache_size;
  }


  static std::string getFileNamePattern(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"FILENAME_PATTERN", FILENAME_PATTERN);
#else
		char* envpara = getenv( "FILENAME_PATTERN" );
		if( envpara ) return std::string(envpara);
#endif
    return FILENAME_PATTERN;
  }


  static int getJPEGQuality(){
    char* envpara = getenv( "JPEG_QUALITY" );
    int jpeg_quality;
    if( envpara ){
      jpeg_quality = atoi( envpara );
      if( jpeg_quality > 100 ) jpeg_quality = 100;
      if( jpeg_quality < 1 ) jpeg_quality = 1;
    }
    else jpeg_quality = JPEG_QUALITY;

    return jpeg_quality;
  }


  static int getMaxCVT(){
    char* envpara = getenv( "MAX_CVT" );
    int max_CVT;
    if( envpara ){
      max_CVT = atoi( envpara );
      if( max_CVT < 64 ) max_CVT = 64;
    }
    else max_CVT = MAX_CVT;

    return max_CVT;
  }


  static int getMaxLayers(){
    char* envpara = getenv( "MAX_LAYERS" );
    int layers;
    if( envpara ) layers = atoi( envpara );
    else layers = MAX_LAYERS;

    return layers;
  }


  static std::string getFileSystemPrefix(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"FILESYSTEM_PREFIX", FILESYSTEM_PREFIX);
#else
		char* envpara = getenv( "FILESYSTEM_PREFIX" );
		if( envpara ) return std::string(envpara);
#endif
    return FILESYSTEM_PREFIX;
  }


  static std::string getWatermark(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"WATERMARK", WATERMARK);
#else
		char* envpara = getenv( "WATERMARK" );
		if( envpara ) return std::string(envpara);
#endif
    return WATERMARK;
  }


  static float getWatermarkProbability(){
    float watermark_probability = WATERMARK_PROBABILITY;
    char* envpara = getenv( "WATERMARK_PROBABILITY" );

    if( envpara ){
      watermark_probability = atof( envpara );
      if( watermark_probability > 1.0 ) watermark_probability = 1.0;
      if( watermark_probability < 0 ) watermark_probability = 0.0;
    }

    return watermark_probability;
  }


  static float getWatermarkOpacity(){
    float watermark_opacity = WATERMARK_OPACITY;
    char* envpara = getenv( "WATERMARK_OPACITY" );

    if( envpara ){
      watermark_opacity = atof( envpara );
      if( watermark_opacity > 1.0 ) watermark_opacity = 1.0;
      if( watermark_opacity < 0 ) watermark_opacity = 0.0;
    }

    return watermark_opacity;
  }


  static std::string getMemcachedServers(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"MEMCACHED_SERVERS", LIBMEMCACHED_SERVERS);
#else
		char* envpara = getenv( "MEMCACHED_SERVERS" );
		if( envpara ) return std::string(envpara);
#endif
    return LIBMEMCACHED_SERVERS;
  }


  static unsigned int getMemcachedTimeout(){
    char* envpara = getenv( "MEMCACHED_TIMEOUT" );
    unsigned int memcached_timeout;
    if( envpara ) memcached_timeout = atoi( envpara );
    else memcached_timeout = LIBMEMCACHED_TIMEOUT;

    return memcached_timeout;
  }


  static unsigned int getInterpolation(){
    char* envpara = getenv( "INTERPOLATION" );
    unsigned int interpolation;
    if( envpara ) interpolation = atoi( envpara );
    else interpolation = INTERPOLATION;

    return interpolation;
  }


  static std::string getCORS(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"CORS", CORS);
#else
		char* envpara = getenv( "CORS" );
		if( envpara ) return std::string(envpara);
#endif
    return CORS;
  }


  static std::string getBaseURL(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"BASE_URL", BASE_URL);
#else
		char* envpara = getenv( "BASE_URL" );
		if( envpara ) return std::string(envpara);
#endif
    return BASE_URL;
  }


  static std::string getCacheControl(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"CACHE_CONTROL", CACHE_CONTROL);
#else
		char* envpara = getenv( "CACHE_CONTROL" );
		if( envpara ) return std::string(envpara);
#endif
    return CACHE_CONTROL;
  }


  static bool getAllowUpscaling(){
    char* envpara = getenv( "ALLOW_UPSCALING" );
    bool allow_upscaling;
    if( envpara ) allow_upscaling =  atoi( envpara ); // Implicit cast to boolean, all values other than '0' treated as true
    else allow_upscaling = ALLOW_UPSCALING;
    return allow_upscaling;
  }


  static std::string getURIMap(){
#if _WIN32
		/* return utf-8 */
		return getEnvUTF8(L"URI_MAP", URI_MAP);
#else
		char* envpara = getenv( "URI_MAP" );
		if( envpara ) return std::string(envpara);
#endif
    return URI_MAP;
  }


  static unsigned int getEmbedICC(){
    char* envpara = getenv( "EMBED_ICC" );
    bool embed;
    if( envpara ) embed = atoi( envpara );
    else embed = EMBED_ICC;
    return embed;
  }

};


#endif
