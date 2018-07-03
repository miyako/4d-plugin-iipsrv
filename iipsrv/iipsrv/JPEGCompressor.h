/*  JPEG class wrapper to ijg jpeg library

    Copyright (C) 2000-2017 Ruven Pillay.

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



#ifndef _JPEGCOMPRESSOR_H
#define _JPEGCOMPRESSOR_H


#include "Compressor.h"


// Fix missing snprintf in Windows
#if _MSC_VER
#define snprintf _snprintf
#endif


extern "C"{
/* Undefine this to prevent compiler warning
 */
#undef HAVE_STDLIB_H
#include <jpeglib.h>
}



/// Expanded data destination object for buffered output used by IJG JPEG library


typedef struct {
  struct jpeg_destination_mgr pub;   /**< public fields */

  size_t size;                       /**< size of source data */
  JOCTET *buffer;		     /**< working buffer */
  unsigned char* source;             /**< source data */
  unsigned int strip_height;         /**< used for stream-based encoding */

} iip_destination_mgr;

typedef iip_destination_mgr * iip_dest_ptr;



/// Wrapper class to the IJG JPEG library

class JPEGCompressor: public Compressor{
	
 private:

  /// the width, height and number of channels per sample for the image
  unsigned int width, height, channels;

  /// The JPEG quality factor
	//  int qualityLevel; // this hides the base class instance variable!!!

  /// Buffer for the JPEG header
  unsigned char header[1024];

  /// Buffer for the image data
  unsigned char *data;

  /// Size of the JPEG header 
  unsigned int header_size;

  /// JPEG library objects
  struct jpeg_compress_struct cinfo;
  struct jpeg_error_mgr jerr;
  iip_destination_mgr dest_mgr;
  iip_dest_ptr dest;

  /// Write ICC profile
  void writeICCProfile();

  /// Write XMP metadata
  void writeXMPMetadata();


 public:

  /// Constructor
  /** @param quality JPEG Quality factor (0-100) */
  JPEGCompressor( int quality ) { qualityLevel = quality; dest = NULL; };


  /// Set the compression quality
  /** @param factor Quality factor (0-100) */
  inline void setQuality( int factor ) {
    if( factor < 0 ) qualityLevel = 0;
    else if( factor > 100 ) qualityLevel = 100;
    else qualityLevel = factor;
  };


  /// Get the current quality level
  int getQuality() { return qualityLevel; }


  /// Initialise strip based compression
  /** If we are doing a strip based encoding, we need to first initialise
      with InitCompression, then compress a single strip at a time using
      CompressStrip and finally clean up using Finish
      @param rawtile tile containing the image to be compressed
      @param strip_height pixel height of the strip we want to compress
      @return header size
   */
  void InitCompression( const RawTile& rawtile, unsigned int strip_height );

  /// Compress a strip of image data
  /** @param s source image data
      @param o output buffer
      @param tile_height pixel height of the tile we are compressing
   */
  unsigned int CompressStrip( unsigned char* s, unsigned char* o, unsigned int tile_height );

  /// Finish the strip based compression and free memory
  /** @param output output buffer
      @return size of output generated
   */
  unsigned int Finish( unsigned char* output );

  /// Compress an entire buffer of image data at once in one command
  /** @param t tile of image data */
  int Compress( RawTile& t );

  /// Return the JPEG header size
  inline unsigned int getHeaderSize() { return header_size; }

  /// Return a pointer to the header itself
  inline unsigned char* getHeader() { return header; }

  /// Return the JPEG mime type
  inline const char* getMimeType(){ return "image/jpeg"; }

  /// Return the image filename suffix
  inline const char* getSuffix(){ return "jpg"; }

};


#endif
