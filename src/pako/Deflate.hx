package pako;

import haxe.io.UInt8Array;
import haxe.zip.FlushMode;
import pako.Deflate.DeflateOptions;
import pako.zlib.Deflate as ZlibDeflate;
import pako.utils.Common;
import pako.zlib.Messages;
import pako.zlib.ZStream;
import pako.zlib.Constants;
import pako.zlib.Constants.CompressionLevel;
import pako.zlib.GZHeader;


typedef DeflateOptions = {
  @:optional var level:Int;
  @:optional var method:Int;
  @:optional var chunkSize:Int;
  @:optional var windowBits:Int;
  @:optional var memLevel:Int;
  @:optional var strategy:Int;
  @:optional var raw:Bool;
  @:optional var gzip:Bool;
  @:optional var header:GZHeader;
  @:optional var dictionary:UInt8Array;
  //to: ''
}

/* Public constants ==========================================================*/
/* ===========================================================================*/
/*
var Z_NO_FLUSH      = 0;
var Z_FINISH        = 4;

var Z_OK            = 0;
var Z_STREAM_END    = 1;
var Z_SYNC_FLUSH    = 2;

var Z_DEFAULT_COMPRESSION = -1;

var Z_DEFAULT_STRATEGY    = 0;

var Z_DEFLATED  = 8;

/* ===========================================================================*/


/**
 * class Deflate
 *
 * Generic JS-style wrapper for zlib calls. If you don't need
 * streaming behaviour - use more simple functions: [[deflate]],
 * [[deflateRaw]] and [[gzip]].
 **/

/* internal
 * Deflate.chunks -> Array
 *
 * Chunks of output data, if [[Deflate#onData]] not overriden.
 **/

/**
 * Deflate.result -> Uint8Array|Array
 *
 * Compressed result, generated by default [[Deflate#onData]]
 * and [[Deflate#onEnd]] handlers. Filled after you push last chunk
 * (call [[Deflate#push]] with `Z_FINISH` / `true` param)  or if you
 * push a chunk with explicit flush (call [[Deflate#push]] with
 * `Z_SYNC_FLUSH` param).
 **/

/**
 * Deflate.err -> Number
 *
 * Error code after deflate finished. 0 (Z_OK) on success.
 * You will not need it in real life, because deflate errors
 * are possible only on wrong options or bad `onData` / `onEnd`
 * custom handlers.
 **/

/**
 * Deflate.msg -> String
 *
 * Error message, if [[Deflate.err]] != 0
 **/


/**
 * new Deflate(options)
 * - options (Object): zlib deflate options.
 *
 * Creates new deflator instance with specified params. Throws exception
 * on bad params. Supported options:
 *
 * - `level`
 * - `windowBits`
 * - `memLevel`
 * - `strategy`
 * - `dictionary`
 * 
 * [http://zlib.net/manual.html#Advanced](http://zlib.net/manual.html#Advanced)
 * for more information on these.
 *
 * Additional options, for internal needs:
 *
 * - `chunkSize` - size of generated data chunks (16K by default)
 * - `raw` (Boolean) - do raw deflate
 * - `gzip` (Boolean) - create gzip wrapper
 * - `to` (String) - if equal to 'string', then result will be "binary string"
 *    (each char code [0..255])
 * - `header` (Object) - custom header for gzip
 *   - `text` (Boolean) - true if compressed data believed to be text
 *   - `time` (Number) - modification time, unix timestamp
 *   - `os` (Number) - operation system code
 *   - `extra` (Array) - array of bytes with extra data (max 65536)
 *   - `name` (String) - file name (binary string)
 *   - `comment` (String) - comment (binary string)
 *   - `hcrc` (Boolean) - true if header crc should be added
 *
 * ##### Example:
 *
 * ```javascript
 * var pako = require('pako')
 *   , chunk1 = Uint8Array([1,2,3,4,5,6,7,8,9])
 *   , chunk2 = Uint8Array([10,11,12,13,14,15,16,17,18,19]);
 *
 * var deflate = new pako.Deflate({ level: 3});
 *
 * deflate.push(chunk1, false);
 * deflate.push(chunk2, true);  // true -> last chunk
 *
 * if (deflate.err) { throw new Error(deflate.err); }
 *
 * console.log(deflate.result);
 * ```
 **/
class Deflate
{
  static var DEFAULT_OPTIONS:DeflateOptions = {
    level: CompressionLevel.Z_DEFAULT_COMPRESSION,
    method: Method.Z_DEFLATED,
    chunkSize: 16384,
    windowBits: 15,
    memLevel: 8,
    strategy: Strategy.Z_DEFAULT_STRATEGY,
    raw: false,
    gzip: false,
    header: null,
    dictionary: null,
    //to: ''
  }
  
  public var options:DeflateOptions = null;
  
  public var err:Int    = ErrorStatus.Z_OK;      // error code, if happens (0 = Z_OK)
  public var msg:String    = '';     // error message
  public var ended:Bool  = false;  // used to avoid multiple onEnd() calls
  public var chunks:Array<UInt8Array> = [];     // chunks of compressed data

  public var strm:ZStream = new ZStream();

  public var result:UInt8Array = null;
  
  public function new(options:DeflateOptions = null) {
    
    this.options = { };
    this.options.level = (options != null && options.level != null) ? options.level : DEFAULT_OPTIONS.level;
    this.options.method = (options != null && options.method != null) ? options.method : DEFAULT_OPTIONS.method;
    this.options.chunkSize = (options != null && options.chunkSize != null) ? options.chunkSize : DEFAULT_OPTIONS.chunkSize;
    this.options.windowBits = (options != null && options.windowBits != null) ? options.windowBits : DEFAULT_OPTIONS.windowBits;
    this.options.memLevel = (options != null && options.memLevel != null) ? options.memLevel : DEFAULT_OPTIONS.memLevel;
    this.options.strategy = (options != null && options.strategy != null) ? options.strategy : DEFAULT_OPTIONS.strategy;
    this.options.raw = (options != null && options.raw != null) ? options.raw : DEFAULT_OPTIONS.raw;
    this.options.gzip = (options != null && options.gzip != null) ? options.gzip : DEFAULT_OPTIONS.gzip;
    this.options.header = (options != null && options.header != null) ? options.header : DEFAULT_OPTIONS.header;
    this.options.dictionary = (options != null && options.dictionary != null) ? options.dictionary : DEFAULT_OPTIONS.dictionary;
    
    //NOTE(hx): both raw and gzip are false by default?
    if (this.options.raw && (this.options.windowBits > 0)) {
      this.options.windowBits = -this.options.windowBits;
    } else if (this.options.gzip && (this.options.windowBits > 0) && (this.options.windowBits < 16)) {
      this.options.windowBits += 16;
    }

    this.onData = _onData;
    this.onEnd = _onEnd;
    
    strm.avail_out = 0;

    var status = ZlibDeflate.deflateInit2(
      this.strm,
      this.options.level,
      this.options.method,
      this.options.windowBits,
      this.options.memLevel,
      this.options.strategy
    );

    if (status != ErrorStatus.Z_OK) {
      throw Messages.get(status);
    }

    if (this.options.header != null) {
      ZlibDeflate.deflateSetHeader(this.strm, this.options.header);
    }
		
    //NOTE(hx): only supporting UInt8Array
    if (this.options.dictionary != null) {
      status = ZlibDeflate.deflateSetDictionary(this.strm, this.options.dictionary);
    }

    if (status != ErrorStatus.Z_OK) {
      throw Messages.get(status);
    }
  }

  /**
   * Deflate#push(data[, mode]) -> Boolean
   * - data (Uint8Array|Array|ArrayBuffer|String): input data. Strings will be
   *   converted to utf8 byte sequence.
   * - mode (Number|Boolean): 0..6 for corresponding Z_NO_FLUSH..Z_TREE modes.
   *   See constants. Skipped or `false` means Z_NO_FLUSH, `true` meansh Z_FINISH.
   *
   * Sends input data to deflate pipe, generating [[Deflate#onData]] calls with
   * new compressed chunks. Returns `true` on success. The last data block must have
   * mode Z_FINISH (or `true`). That will flush internal pending buffers and call
   * [[Deflate#onEnd]]. For interim explicit flushes (without ending the stream) you
   * can use mode Z_SYNC_FLUSH, keeping the compression context.
   *
   * On fail call [[Deflate#onEnd]] with error code and return false.
   *
   * We strongly recommend to use `Uint8Array` on input for best speed (output
   * array format is detected automatically). Also, don't skip last param and always
   * use the same type in your code (boolean or number). That will improve JS speed.
   *
   * For regular `Array`-s make sure all elements are [0..255].
   *
   * ##### Example
   *
   * ```javascript
   * push(chunk, false); // push one of data chunks
   * ...
   * push(chunk, true);  // push last chunk
   * ```
   **/
  public function push(data:UInt8Array, mode:Dynamic = false) {
    var strm = this.strm;
    var chunkSize = this.options.chunkSize;
    var status, _mode:Int;

    if (this.ended) { return false; }

    //NOTE(hx): search codebase for ~~
    //_mode = (mode == ~~mode) ? mode : ((mode == true) ? Z_FINISH : Z_NO_FLUSH);
    if (Std.is(mode, Int)) _mode = mode;
    else if (Std.is(mode, Bool)) _mode = mode ? Flush.Z_FINISH : Flush.Z_NO_FLUSH;
    else throw "Invalid mode.";

    // Convert data if needed
    //NOTE(hx): only supporting UInt8Array
    /*if (typeof data === 'string') {
      // If we need to compress text, change encoding to utf8.
      strm.input = strings.string2buf(data);
    } else if (toString.call(data) === '[object ArrayBuffer]') {
      strm.input = new Uint8Array(data);
    } else*/ {
      strm.input = data;
    }

    strm.next_in = 0;
    strm.avail_in = strm.input.length;

    do {
      if (strm.avail_out == 0) {
        strm.output = new UInt8Array(chunkSize);
        strm.next_out = 0;
        strm.avail_out = chunkSize;
      }
      status = ZlibDeflate.deflate(strm, _mode);    /* no bad return value */

      if (status != ErrorStatus.Z_STREAM_END && status != ErrorStatus.Z_OK) {
        this.onEnd(status);
        this.ended = true;
        return false;
      }
      if (strm.avail_out == 0 || (strm.avail_in == 0 && (_mode == Flush.Z_FINISH || _mode == Flush.Z_SYNC_FLUSH))) {
        //NOTE(hx): only supporting UInt8Array
        /*if (this.options.to === 'string') {
          this.onData(strings.buf2binstring(utils.shrinkBuf(strm.output, strm.next_out)));
        } else */ {
          //NOTE(hx): cast ok?
          this.onData(Common.shrinkBuf(strm.output, strm.next_out));
        }
      }
    } while ((strm.avail_in > 0 || strm.avail_out == 0) && status != ErrorStatus.Z_STREAM_END);

    // Finalize on the last chunk.
    if (_mode == Flush.Z_FINISH) {
      status = ZlibDeflate.deflateEnd(this.strm);
      this.onEnd(status);
      this.ended = true;
      return status == ErrorStatus.Z_OK;
    }

    // callback interim results if Z_SYNC_FLUSH.
    if (_mode == Flush.Z_SYNC_FLUSH) {
      this.onEnd(ErrorStatus.Z_OK);
      strm.avail_out = 0;
      return true;
    }

    return true;
  }


  /**
   * Deflate#onData(chunk) -> Void
   * - chunk (Uint8Array|Array|String): ouput data. Type of array depends
   *   on js engine support. When string output requested, each chunk
   *   will be string.
   *
   * By default, stores data blocks in `chunks[]` property and glue
   * those in `onEnd`. Override this handler, if you need another behaviour.
   **/
  public var onData:UInt8Array->Void;
  
  function _onData(chunk:UInt8Array) {
    this.chunks.push(chunk);
  }

  
  /**
   * Deflate#onEnd(status) -> Void
   * - status (Number): deflate status. 0 (Z_OK) on success,
   *   other if not.
   *
   * Called once after you tell deflate that the input stream is
   * complete (Z_FINISH) or should be flushed (Z_SYNC_FLUSH)
   * or if an error happened. By default - join collected chunks,
   * free memory and fill `results` / `err` properties.
   **/
  public var onEnd:Int->Void;
  
  function _onEnd(status:Int) {
    // On success - join
    if (status == ErrorStatus.Z_OK) {
      //NOTE(hx): only supporting UInt8Array
      /*if (this.options.to === 'string') {
        this.result = this.chunks.join('');
      } else*/ {
        this.result = Common.flattenChunks(this.chunks);
      }
    }
    this.chunks = [];
    this.err = status;
    this.msg = this.strm.msg;
  }
}

/*
exports.Deflate = Deflate;
exports.deflate = deflate;
exports.deflateRaw = deflateRaw;
exports.gzip = gzip;
*/