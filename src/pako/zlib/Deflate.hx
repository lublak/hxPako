package pako.zlib;

import haxe.Constraints.Function;
import haxe.io.UInt16Array;
import haxe.io.UInt8Array;
import pako.utils.Common;
import pako.zlib.Constants;
import pako.zlib.Trees;
import pako.zlib.Adler32;
import pako.zlib.CRC32;
import pako.zlib.Messages;

/* Public constants ==========================================================*/
/* ===========================================================================*/


/* Allowed flush values; see deflate() and inflate() below for details */
/*var Z_NO_FLUSH      = 0;
var Z_PARTIAL_FLUSH = 1;
//var Z_SYNC_FLUSH    = 2;
var Z_FULL_FLUSH    = 3;
var Z_FINISH        = 4;
var Z_BLOCK         = 5;
//var Z_TREES         = 6;
*/

/* Return codes for the compression/decompression functions. Negative values
 * are errors, positive values are used for special but normal events.
 */
/*var Z_OK            = 0;
var Z_STREAM_END    = 1;
//var Z_NEED_DICT     = 2;
//var Z_ERRNO         = -1;
var Z_STREAM_ERROR  = -2;
var Z_DATA_ERROR    = -3;
//var Z_MEM_ERROR     = -4;
var Z_BUF_ERROR     = -5;
//var Z_VERSION_ERROR = -6;
*/

/* compression levels */
/*//var Z_NO_COMPRESSION      = 0;
//var Z_BEST_SPEED          = 1;
//var Z_BEST_COMPRESSION    = 9;
var Z_DEFAULT_COMPRESSION = -1;
*/

/*var Z_FILTERED            = 1;
var Z_HUFFMAN_ONLY        = 2;
var Z_RLE                 = 3;
var Z_FIXED               = 4;
var Z_DEFAULT_STRATEGY    = 0;
*/

/* Possible values of the data_type field (though see inflate()) */
/*//var Z_BINARY              = 0;
//var Z_TEXT                = 1;
//var Z_ASCII               = 1; // = Z_TEXT
var Z_UNKNOWN             = 2;
*/

/* The deflate compression method */
/*var Z_DEFLATED  = 8;
*/

/*============================================================================*/
class Deflate
{
  static inline var deflateInfo:String = 'pako deflate (from Nodeca project)';

  static inline var MAX_MEM_LEVEL = 9;
/* Maximum value for memLevel in deflateInit2 */
  static inline var MAX_WBITS = 15;
/* 32K LZ77 window */
  static inline var DEF_MEM_LEVEL = 8;


  static inline var LENGTH_CODES  = 29;
/* number of length codes, not counting the special END_BLOCK code */
  static inline var LITERALS      = 256;
/* number of literal bytes 0..255 */
  static inline var L_CODES       = LITERALS + 1 + LENGTH_CODES;
/* number of Literal or Length codes, including the END_BLOCK code */
  static inline var D_CODES       = 30;
/* number of distance codes */
  static inline var BL_CODES      = 19;
/* number of codes used to transfer the bit lengths */
  static inline var HEAP_SIZE     = 2*L_CODES + 1;
/* maximum heap size */
  static inline var MAX_BITS  = 15;
/* All codes must not exceed MAX_BITS bits */

  static inline var MIN_MATCH = 3;
  static inline var MAX_MATCH = 258;
  static inline var MIN_LOOKAHEAD = (MAX_MATCH + MIN_MATCH + 1);

  static inline var PRESET_DICT = 0x20;

  static inline var INIT_STATE = 42;
  static inline var EXTRA_STATE = 69;
  static inline var NAME_STATE = 73;
  static inline var COMMENT_STATE = 91;
  static inline var HCRC_STATE = 103;
  static inline var BUSY_STATE = 113;
  static inline var FINISH_STATE = 666;

  static inline var BS_NEED_MORE      = 1; /* block not completed, need more input or more output */
  static inline var BS_BLOCK_DONE     = 2; /* block flush performed */
  static inline var BS_FINISH_STARTED = 3; /* finish started, need only more output at next deflate */
  static inline var BS_FINISH_DONE    = 4; /* finish done, accept no more input or output */

  static inline var OS_CODE = 0x03; // Unix :) . Don't detect, use this default.

  
  static inline function err(strm:ZStream, errorCode) {
    strm.msg = Messages.get(errorCode);
    return errorCode;
  }

  static inline function rank(f) {
    return ((f) << 1) - ((f) > 4 ? 9 : 0);
  }


  /* =========================================================================
   * Flush as much pending output as possible. All deflate() output goes
   * through this function so some applications may wish to modify it
   * to avoid allocating a large strm->output buffer and copying into it.
   * (See also read_buf()).
   */
  static function flush_pending(strm:ZStream) {
    var s = strm.deflateState;

    //_tr_flush_bits(s);
    var len = s.pending;
    if (len > strm.avail_out) {
      len = strm.avail_out;
    }
    if (len == 0) { return; }

    Common.arraySet(cast strm.output, cast s.pending_buf, s.pending_out, len, strm.next_out);
    strm.next_out += len;
    s.pending_out += len;
    strm.total_out += len;
    strm.avail_out -= len;
    s.pending -= len;
    if (s.pending == 0) {
      s.pending_out = 0;
    }
  }


  static inline function flush_block_only (s:DeflateState, last) {
    Trees._tr_flush_block(s, (s.block_start >= 0 ? s.block_start : -1), s.strstart - s.block_start, last);
    s.block_start = s.strstart;
    flush_pending(s.strm);
  }


  static inline function put_byte(s:DeflateState, b) {
    s.pending_buf[s.pending++] = b;
  }


  /* =========================================================================
   * Put a short in the pending buffer. The 16-bit value is put in MSB order.
   * IN assertion: the stream state is correct and there is enough room in
   * pending_buf.
   */
  static inline function putShortMSB(s:DeflateState, b) {
  //  put_byte(s, (Byte)(b >> 8));
  //  put_byte(s, (Byte)(b & 0xff));
    s.pending_buf[s.pending++] = (b >>> 8) & 0xff;
    s.pending_buf[s.pending++] = b & 0xff;
  }


  /* ===========================================================================
   * Read a new buffer from the current input stream, update the adler32
   * and total number of bytes read.  All deflate() input goes through
   * this function so some applications may wish to modify it to avoid
   * allocating a large strm->input buffer and copying from it.
   * (See also flush_pending()).
   */
  static function read_buf(strm:ZStream, buf, start, size) {
    var len = strm.avail_in;

    if (len > size) { len = size; }
    if (len == 0) { return 0; }

    strm.avail_in -= len;

    Common.arraySet(cast buf, cast strm.input, strm.next_in, len, start);
    if (strm.deflateState.wrap == 1) {
      strm.adler = Adler32.adler32(strm.adler, buf, len, start);
    }

    else if (strm.deflateState.wrap == 2) {
      strm.adler = CRC32.crc32(strm.adler, buf, len, start);
    }

    strm.next_in += len;
    strm.total_in += len;

    return len;
  }


  /* ===========================================================================
   * Set match_start to the longest match starting at the given string and
   * return its length. Matches shorter or equal to prev_length are discarded,
   * in which case the result is equal to prev_length and match_start is
   * garbage.
   * IN assertions: cur_match is the head of the hash chain for the current
   *   string (strstart) and its distance is <= MAX_DIST, and prev_length >= 1
   * OUT assertion: the match length is not greater than s->lookahead.
   */
  static function longest_match(s:DeflateState, cur_match) {
    var chain_length = s.max_chain_length;      /* max hash chain length */
    var scan = s.strstart; /* current string */
    var match;                       /* matched string */
    var len;                           /* length of current match */
    var best_len = s.prev_length;              /* best match length so far */
    var nice_match = s.nice_match;             /* stop if match long enough */
    var limit = (s.strstart > (s.w_size - MIN_LOOKAHEAD)) ?
        s.strstart - (s.w_size - MIN_LOOKAHEAD) : 0/*NIL*/;

    var _win = s.window; // shortcut

    var wmask = s.w_mask;
    var prev  = s.prev;

    /* Stop when cur_match becomes <= limit. To simplify the code,
     * we prevent matches with the string of window index 0.
     */

    var strend = s.strstart + MAX_MATCH;
    var scan_end1  = _win[scan + best_len - 1];
    var scan_end   = _win[scan + best_len];

    /* The code is optimized for HASH_BITS >= 8 and MAX_MATCH-2 multiple of 16.
     * It is easy to get rid of this optimization if necessary.
     */
    // Assert(s->hash_bits >= 8 && MAX_MATCH == 258, "Code too clever");

    /* Do not waste too much time if we already have a good match: */
    if (s.prev_length >= s.good_match) {
      chain_length >>= 2;
    }
    /* Do not look for matches beyond the end of the input. This is necessary
     * to make deflate deterministic.
     */
    if (nice_match > s.lookahead) { nice_match = s.lookahead; }

    // Assert((ulg)s->strstart <= s->window_size-MIN_LOOKAHEAD, "need lookahead");

    do {
      // Assert(cur_match < s->strstart, "no future");
      match = cur_match;

      /* Skip to next match if the match length cannot increase
       * or if the match length is less than 2.  Note that the checks below
       * for insufficient lookahead only occur occasionally for performance
       * reasons.  Therefore uninitialized memory will be accessed, and
       * conditional jumps will be made that depend on those values.
       * However the length of the match is limited to the lookahead, so
       * the output of deflate is not affected by the uninitialized values.
       */

      if (_win[match + best_len]     != scan_end  ||
          _win[match + best_len - 1] != scan_end1 ||
          _win[match]                != _win[scan] ||
          _win[++match]              != _win[scan + 1]) {
        continue;
      }

      /* The check at best_len-1 can be removed because it will be made
       * again later. (This heuristic is not always a win.)
       * It is not necessary to compare scan[2] and match[2] since they
       * are always equal when the other bytes match, given that
       * the hash keys are equal and that HASH_BITS >= 8.
       */
      scan += 2;
      match++;
      // Assert(*scan == *match, "match[2]?");

      /* We check for insufficient lookahead only every 8th comparison;
       * the 256th check will be made at strstart+258.
       */
      do {
        /*jshint noempty:false*/
      } while (_win[++scan] == _win[++match] && _win[++scan] == _win[++match] &&
               _win[++scan] == _win[++match] && _win[++scan] == _win[++match] &&
               _win[++scan] == _win[++match] && _win[++scan] == _win[++match] &&
               _win[++scan] == _win[++match] && _win[++scan] == _win[++match] &&
               scan < strend);

      // Assert(scan <= s->window+(unsigned)(s->window_size-1), "wild scan");

      len = MAX_MATCH - (strend - scan);
      scan = strend - MAX_MATCH;

      if (len > best_len) {
        s.match_start = cur_match;
        best_len = len;
        if (len >= nice_match) {
          break;
        }
        scan_end1  = _win[scan + best_len - 1];
        scan_end   = _win[scan + best_len];
      }
    } while ((cur_match = prev[cur_match & wmask]) > limit && --chain_length != 0);

    if (best_len <= s.lookahead) {
      return best_len;
    }
    return s.lookahead;
  }


  /* ===========================================================================
   * Fill the window when the lookahead becomes insufficient.
   * Updates strstart and lookahead.
   *
   * IN assertion: lookahead < MIN_LOOKAHEAD
   * OUT assertions: strstart <= window_size-MIN_LOOKAHEAD
   *    At least one byte has been read, or avail_in == 0; reads are
   *    performed for at least two bytes (required for the zip translate_eol
   *    option -- not supported here).
   */
  static function fill_window(s:DeflateState) {
    var _w_size = s.w_size;
    var p, n, m, more, str;

    //Assert(s->lookahead < MIN_LOOKAHEAD, "already enough lookahead");

    do {
      more = s.window_size - s.lookahead - s.strstart;

      // JS ints have 32 bit, block below not needed
      /* Deal with !@#$% 64K limit: */
      //if (sizeof(int) <= 2) {
      //    if (more == 0 && s->strstart == 0 && s->lookahead == 0) {
      //        more = wsize;
      //
      //  } else if (more == (unsigned)(-1)) {
      //        /* Very unlikely, but possible on 16 bit machine if
      //         * strstart == 0 && lookahead == 1 (input done a byte at time)
      //         */
      //        more--;
      //    }
      //}


      /* If the window is almost full and there is insufficient lookahead,
       * move the upper half to the lower one to make room in the upper half.
       */
      if (s.strstart >= _w_size + (_w_size - MIN_LOOKAHEAD)) {

        Common.arraySet(cast s.window, cast s.window, _w_size, _w_size, 0);
        s.match_start -= _w_size;
        s.strstart -= _w_size;
        /* we now have strstart >= MAX_DIST */
        s.block_start -= _w_size;

        /* Slide the hash table (could be avoided with 32 bit values
         at the expense of memory usage). We slide even when level == 0
         to keep the hash table consistent if we switch back to level > 0
         later. (Using level 0 permanently is not an optimal usage of
         zlib, so we don't care about this pathological case.)
         */

        n = s.hash_size;
        p = n;
        //NOTE(hx): check n--
        do {
          m = s.head[--p];
          s.head[p] = (m >= _w_size ? m - _w_size : 0);
        } while (--n != 0);

        n = _w_size;
        p = n;
        do {
          m = s.prev[--p];
          s.prev[p] = (m >= _w_size ? m - _w_size : 0);
          /* If n is not on any hash chain, prev[n] is garbage but
           * its value will never be used.
           */
        } while (--n != 0);

        more += _w_size;
      }
      if (s.strm.avail_in == 0) {
        break;
      }

      /* If there was no sliding:
       *    strstart <= WSIZE+MAX_DIST-1 && lookahead <= MIN_LOOKAHEAD - 1 &&
       *    more == window_size - lookahead - strstart
       * => more >= window_size - (MIN_LOOKAHEAD-1 + WSIZE + MAX_DIST-1)
       * => more >= window_size - 2*WSIZE + 2
       * In the BIG_MEM or MMAP case (not yet supported),
       *   window_size == input_size + MIN_LOOKAHEAD  &&
       *   strstart + s->lookahead <= input_size => more >= MIN_LOOKAHEAD.
       * Otherwise, window_size == 2*WSIZE so more >= 2.
       * If there was sliding, more >= WSIZE. So in all cases, more >= 2.
       */
      //Assert(more >= 2, "more < 2");
      n = read_buf(s.strm, s.window, s.strstart + s.lookahead, more);
      s.lookahead += n;

      /* Initialize the hash value now that we have some input: */
      if (s.lookahead + s.insert >= MIN_MATCH) {
        str = s.strstart - s.insert;
        s.ins_h = s.window[str];

        /* UPDATE_HASH(s, s->ins_h, s->window[str + 1]); */
        s.ins_h = ((s.ins_h << s.hash_shift) ^ s.window[str + 1]) & s.hash_mask;
  //#if MIN_MATCH != 3
  //        Call update_hash() MIN_MATCH-3 more times
  //#endif
        while (s.insert != 0) {
          /* UPDATE_HASH(s, s->ins_h, s->window[str + MIN_MATCH-1]); */
          s.ins_h = ((s.ins_h << s.hash_shift) ^ s.window[str + MIN_MATCH-1]) & s.hash_mask;

          s.prev[str & s.w_mask] = s.head[s.ins_h];
          s.head[s.ins_h] = str;
          str++;
          s.insert--;
          if (s.lookahead + s.insert < MIN_MATCH) {
            break;
          }
        }
      }
      /* If the whole input has less than MIN_MATCH bytes, ins_h is garbage,
       * but this is not important since only literal bytes will be emitted.
       */

    } while (s.lookahead < MIN_LOOKAHEAD && s.strm.avail_in != 0);

    /* If the WIN_INIT bytes after the end of the current data have never been
     * written, then zero those bytes in order to avoid memory check reports of
     * the use of uninitialized (or uninitialised as Julian writes) bytes by
     * the longest match routines.  Update the high water mark for the next
     * time through here.  WIN_INIT is set to MAX_MATCH since the longest match
     * routines allow scanning to strstart + MAX_MATCH, ignoring lookahead.
     */
  //  if (s.high_water < s.window_size) {
  //    var curr = s.strstart + s.lookahead;
  //    var init = 0;
  //
  //    if (s.high_water < curr) {
  //      /* Previous high water mark below current data -- zero WIN_INIT
  //       * bytes or up to end of window, whichever is less.
  //       */
  //      init = s.window_size - curr;
  //      if (init > WIN_INIT)
  //        init = WIN_INIT;
  //      zmemzero(s->window + curr, (unsigned)init);
  //      s->high_water = curr + init;
  //    }
  //    else if (s->high_water < (ulg)curr + WIN_INIT) {
  //      /* High water mark at or above current data, but below current data
  //       * plus WIN_INIT -- zero out to current data plus WIN_INIT, or up
  //       * to end of window, whichever is less.
  //       */
  //      init = (ulg)curr + WIN_INIT - s->high_water;
  //      if (init > s->window_size - s->high_water)
  //        init = s->window_size - s->high_water;
  //      zmemzero(s->window + s->high_water, (unsigned)init);
  //      s->high_water += init;
  //    }
  //  }
  //
  //  Assert((ulg)s->strstart <= s->window_size - MIN_LOOKAHEAD,
  //    "not enough room for search");
  }

  /* ===========================================================================
   * Copy without compression as much as possible from the input stream, return
   * the current block state.
   * This function does not insert new strings in the dictionary since
   * uncompressible data is probably not useful. This function is used
   * only for the level=0 compression option.
   * NOTE: this function should be optimized to avoid extra copying from
   * window to pending_buf.
   */
  static function deflate_stored(s:DeflateState, flush:Int) {
    /* Stored blocks are limited to 0xffff bytes, pending_buf is limited
     * to pending_buf_size, and each stored block has a 5 byte header:
     */
    var max_block_size = 0xffff;

    if (max_block_size > s.pending_buf_size - 5) {
      max_block_size = s.pending_buf_size - 5;
    }

    /* Copy as much as possible from input to output: */
    while (true) {
      /* Fill the window as much as possible: */
      if (s.lookahead <= 1) {

        //Assert(s->strstart < s->w_size+MAX_DIST(s) ||
        //  s->block_start >= (long)s->w_size, "slide too late");
  //      if (!(s.strstart < s.w_size + (s.w_size - MIN_LOOKAHEAD) ||
  //        s.block_start >= s.w_size)) {
  //        throw  new Error("slide too late");
  //      }

        fill_window(s);
        if (s.lookahead == 0 && flush == Flush.Z_NO_FLUSH) {
          return BS_NEED_MORE;
        }

        if (s.lookahead == 0) {
          break;
        }
        /* flush the current block */
      }
      //Assert(s->block_start >= 0L, "block gone");
  //    if (s.block_start < 0) throw new Error("block gone");

      s.strstart += s.lookahead;
      s.lookahead = 0;

      /* Emit a stored block if pending_buf will be full: */
      var max_start = s.block_start + max_block_size;

      if (s.strstart == 0 || s.strstart >= max_start) {
        /* strstart == 0 is possible when wraparound on 16-bit machine */
        s.lookahead = s.strstart - max_start;
        s.strstart = max_start;
        /*** FLUSH_BLOCK(s, 0); ***/
        flush_block_only(s, false);
        if (s.strm.avail_out == 0) {
          return BS_NEED_MORE;
        }
        /***/


      }
      /* Flush if we may have to slide, otherwise block_start may become
       * negative and the data will be gone:
       */
      if (s.strstart - s.block_start >= (s.w_size - MIN_LOOKAHEAD)) {
        /*** FLUSH_BLOCK(s, 0); ***/
        flush_block_only(s, false);
        if (s.strm.avail_out == 0) {
          return BS_NEED_MORE;
        }
        /***/
      }
    }

    s.insert = 0;

    if (flush == Flush.Z_FINISH) {
      /*** FLUSH_BLOCK(s, 1); ***/
      flush_block_only(s, true);
      if (s.strm.avail_out == 0) {
        return BS_FINISH_STARTED;
      }
      /***/
      return BS_FINISH_DONE;
    }

    if (s.strstart > s.block_start) {
      /*** FLUSH_BLOCK(s, 0); ***/
      flush_block_only(s, false);
      if (s.strm.avail_out == 0) {
        return BS_NEED_MORE;
      }
      /***/
    }

    return BS_NEED_MORE;
  }

  /* ===========================================================================
   * Compress as much as possible from the input stream, return the current
   * block state.
   * This function does not perform lazy evaluation of matches and inserts
   * new strings in the dictionary only for unmatched strings or for short
   * matches. It is used only for the fast compression options.
   */
  static function deflate_fast(s:DeflateState, flush) {
    var hash_head;        /* head of the hash chain */
    var bflush;           /* set if current block must be flushed */

    while (true) {
      /* Make sure that we always have enough lookahead, except
       * at the end of the input file. We need MAX_MATCH bytes
       * for the next match, plus MIN_MATCH bytes to insert the
       * string following the next match.
       */
      if (s.lookahead < MIN_LOOKAHEAD) {
        fill_window(s);
        if (s.lookahead < MIN_LOOKAHEAD && flush == Flush.Z_NO_FLUSH) {
          return BS_NEED_MORE;
        }
        if (s.lookahead == 0) {
          break; /* flush the current block */
        }
      }

      /* Insert the string window[strstart .. strstart+2] in the
       * dictionary, and set hash_head to the head of the hash chain:
       */
      hash_head = 0/*NIL*/;
      if (s.lookahead >= MIN_MATCH) {
        /*** INSERT_STRING(s, s.strstart, hash_head); ***/
        s.ins_h = ((s.ins_h << s.hash_shift) ^ s.window[s.strstart + MIN_MATCH - 1]) & s.hash_mask;
        hash_head = s.prev[s.strstart & s.w_mask] = s.head[s.ins_h];
        s.head[s.ins_h] = s.strstart;
        /***/
      }

      /* Find the longest match, discarding those <= prev_length.
       * At this point we have always match_length < MIN_MATCH
       */
      if (hash_head != 0/*NIL*/ && ((s.strstart - hash_head) <= (s.w_size - MIN_LOOKAHEAD))) {
        /* To simplify the code, we prevent matches with the string
         * of window index 0 (in particular we have to avoid a match
         * of the string with itself at the start of the input file).
         */
        s.match_length = longest_match(s, hash_head);
        /* longest_match() sets match_start */
      }
      if (s.match_length >= MIN_MATCH) {
        // check_match(s, s.strstart, s.match_start, s.match_length); // for debug only

        /*** _tr_tally_dist(s, s.strstart - s.match_start,
                       s.match_length - MIN_MATCH, bflush); ***/
        bflush = Trees._tr_tally(s, s.strstart - s.match_start, s.match_length - MIN_MATCH);

        s.lookahead -= s.match_length;

        /* Insert new strings in the hash table only if the match length
         * is not too large. This saves time but degrades compression.
         */
        if (s.match_length <= s.max_lazy_match/*max_insert_length*/ && s.lookahead >= MIN_MATCH) {
          s.match_length--; /* string at strstart already in table */
          do {
            s.strstart++;
            /*** INSERT_STRING(s, s.strstart, hash_head); ***/
            s.ins_h = ((s.ins_h << s.hash_shift) ^ s.window[s.strstart + MIN_MATCH - 1]) & s.hash_mask;
            hash_head = s.prev[s.strstart & s.w_mask] = s.head[s.ins_h];
            s.head[s.ins_h] = s.strstart;
            /***/
            /* strstart never exceeds WSIZE-MAX_MATCH, so there are
             * always MIN_MATCH bytes ahead.
             */
          } while (--s.match_length != 0);
          s.strstart++;
        } else
        {
          s.strstart += s.match_length;
          s.match_length = 0;
          s.ins_h = s.window[s.strstart];
          /* UPDATE_HASH(s, s.ins_h, s.window[s.strstart+1]); */
          s.ins_h = ((s.ins_h << s.hash_shift) ^ s.window[s.strstart + 1]) & s.hash_mask;

  //#if MIN_MATCH != 3
  //                Call UPDATE_HASH() MIN_MATCH-3 more times
  //#endif
          /* If lookahead < MIN_MATCH, ins_h is garbage, but it does not
           * matter since it will be recomputed at next deflate call.
           */
        }
      } else {
        /* No match, output a literal byte */
        //Tracevv((stderr,"%c", s.window[s.strstart]));
        /*** _tr_tally_lit(s, s.window[s.strstart], bflush); ***/
        bflush = Trees._tr_tally(s, 0, s.window[s.strstart]);

        s.lookahead--;
        s.strstart++;
      }
      if (bflush) {
        /*** FLUSH_BLOCK(s, 0); ***/
        flush_block_only(s, false);
        if (s.strm.avail_out == 0) {
          return BS_NEED_MORE;
        }
        /***/
      }
    }
    s.insert = ((s.strstart < (MIN_MATCH-1)) ? s.strstart : MIN_MATCH-1);
    if (flush == Flush.Z_FINISH) {
      /*** FLUSH_BLOCK(s, 1); ***/
      flush_block_only(s, true);
      if (s.strm.avail_out == 0) {
        return BS_FINISH_STARTED;
      }
      /***/
      return BS_FINISH_DONE;
    }
    if (s.last_lit != 0) {
      /*** FLUSH_BLOCK(s, 0); ***/
      flush_block_only(s, false);
      if (s.strm.avail_out == 0) {
        return BS_NEED_MORE;
      }
      /***/
    }
    return BS_BLOCK_DONE;
  }

  /* ===========================================================================
   * Same as above, but achieves better compression. We use a lazy
   * evaluation for matches: a match is finally adopted only if there is
   * no better match at the next window position.
   */
  static function deflate_slow(s:DeflateState, flush) {
    var hash_head;          /* head of hash chain */
    var bflush;              /* set if current block must be flushed */

    var max_insert;

    /* Process the input block. */
    while (true) {
      /* Make sure that we always have enough lookahead, except
       * at the end of the input file. We need MAX_MATCH bytes
       * for the next match, plus MIN_MATCH bytes to insert the
       * string following the next match.
       */
      if (s.lookahead < MIN_LOOKAHEAD) {
        fill_window(s);
        if (s.lookahead < MIN_LOOKAHEAD && flush == Flush.Z_NO_FLUSH) {
          return BS_NEED_MORE;
        }
        if (s.lookahead == 0) { break; } /* flush the current block */
      }

      /* Insert the string window[strstart .. strstart+2] in the
       * dictionary, and set hash_head to the head of the hash chain:
       */
      hash_head = 0/*NIL*/;
      if (s.lookahead >= MIN_MATCH) {
        /*** INSERT_STRING(s, s.strstart, hash_head); ***/
        s.ins_h = ((s.ins_h << s.hash_shift) ^ s.window[s.strstart + MIN_MATCH - 1]) & s.hash_mask;
        hash_head = s.prev[s.strstart & s.w_mask] = s.head[s.ins_h];
        s.head[s.ins_h] = s.strstart;
        /***/
      }

      /* Find the longest match, discarding those <= prev_length.
       */
      s.prev_length = s.match_length;
      s.prev_match = s.match_start;
      s.match_length = MIN_MATCH-1;

      if (hash_head != 0/*NIL*/ && s.prev_length < s.max_lazy_match &&
          s.strstart - hash_head <= (s.w_size-MIN_LOOKAHEAD)/*MAX_DIST(s)*/) {
        /* To simplify the code, we prevent matches with the string
         * of window index 0 (in particular we have to avoid a match
         * of the string with itself at the start of the input file).
         */
        s.match_length = longest_match(s, hash_head);
        /* longest_match() sets match_start */

        if (s.match_length <= 5 &&
           (s.strategy == Strategy.Z_FILTERED || (s.match_length == MIN_MATCH && s.strstart - s.match_start > 4096/*TOO_FAR*/))) {

          /* If prev_match is also MIN_MATCH, match_start is garbage
           * but we will ignore the current match anyway.
           */
          s.match_length = MIN_MATCH-1;
        }
      }
      /* If there was a match at the previous step and the current
       * match is not better, output the previous match:
       */
      if (s.prev_length >= MIN_MATCH && s.match_length <= s.prev_length) {
        max_insert = s.strstart + s.lookahead - MIN_MATCH;
        /* Do not insert strings in hash table beyond this. */

        //check_match(s, s.strstart-1, s.prev_match, s.prev_length);

        /***_tr_tally_dist(s, s.strstart - 1 - s.prev_match,
                       s.prev_length - MIN_MATCH, bflush);***/
        bflush = Trees._tr_tally(s, s.strstart - 1- s.prev_match, s.prev_length - MIN_MATCH);
        /* Insert in hash table all strings up to the end of the match.
         * strstart-1 and strstart are already inserted. If there is not
         * enough lookahead, the last two strings are not inserted in
         * the hash table.
         */
        s.lookahead -= s.prev_length-1;
        s.prev_length -= 2;
        do {
          if (++s.strstart <= max_insert) {
            /*** INSERT_STRING(s, s.strstart, hash_head); ***/
            s.ins_h = ((s.ins_h << s.hash_shift) ^ s.window[s.strstart + MIN_MATCH - 1]) & s.hash_mask;
            hash_head = s.prev[s.strstart & s.w_mask] = s.head[s.ins_h];
            s.head[s.ins_h] = s.strstart;
            /***/
          }
        } while (--s.prev_length != 0);
        s.match_available = false;
        s.match_length = MIN_MATCH-1;
        s.strstart++;

        if (bflush) {
          /*** FLUSH_BLOCK(s, 0); ***/
          flush_block_only(s, false);
          if (s.strm.avail_out == 0) {
            return BS_NEED_MORE;
          }
          /***/
        }

      } else if (s.match_available) {
        /* If there was no match at the previous position, output a
         * single literal. If there was a match but the current match
         * is longer, truncate the previous match to a single literal.
         */
        //Tracevv((stderr,"%c", s->window[s->strstart-1]));
        /*** _tr_tally_lit(s, s.window[s.strstart-1], bflush); ***/
        bflush = Trees._tr_tally(s, 0, s.window[s.strstart-1]);

        if (bflush) {
          /*** FLUSH_BLOCK_ONLY(s, 0) ***/
          flush_block_only(s, false);
          /***/
        }
        s.strstart++;
        s.lookahead--;
        if (s.strm.avail_out == 0) {
          return BS_NEED_MORE;
        }
      } else {
        /* There is no previous match to compare with, wait for
         * the next step to decide.
         */
        s.match_available = true;
        s.strstart++;
        s.lookahead--;
      }
    }
    //Assert (flush != Z_NO_FLUSH, "no flush?");
    if (s.match_available) {
      //Tracevv((stderr,"%c", s->window[s->strstart-1]));
      /*** _tr_tally_lit(s, s.window[s.strstart-1], bflush); ***/
      bflush = Trees._tr_tally(s, 0, s.window[s.strstart-1]);

      s.match_available = false;
    }
    s.insert = s.strstart < MIN_MATCH-1 ? s.strstart : MIN_MATCH-1;
    if (flush == Flush.Z_FINISH) {
      /*** FLUSH_BLOCK(s, 1); ***/
      flush_block_only(s, true);
      if (s.strm.avail_out == 0) {
        return BS_FINISH_STARTED;
      }
      /***/
      return BS_FINISH_DONE;
    }
    if (s.last_lit != 0) {
      /*** FLUSH_BLOCK(s, 0); ***/
      flush_block_only(s, false);
      if (s.strm.avail_out == 0) {
        return BS_NEED_MORE;
      }
      /***/
    }

    return BS_BLOCK_DONE;
  }


  /* ===========================================================================
   * For Z_RLE, simply look for runs of bytes, generate matches only of distance
   * one.  Do not maintain a hash table.  (It will be regenerated if this run of
   * deflate switches away from Z_RLE.)
   */
  static function deflate_rle(s:DeflateState, flush) {
    var bflush;            /* set if current block must be flushed */
    var prev;              /* byte at distance one to match */
    var scan, strend;      /* scan goes up to strend for length of run */

    var _win = s.window;

    while (true) {
      /* Make sure that we always have enough lookahead, except
       * at the end of the input file. We need MAX_MATCH bytes
       * for the longest run, plus one for the unrolled loop.
       */
      if (s.lookahead <= MAX_MATCH) {
        fill_window(s);
        if (s.lookahead <= MAX_MATCH && flush == Flush.Z_NO_FLUSH) {
          return BS_NEED_MORE;
        }
        if (s.lookahead == 0) { break; } /* flush the current block */
      }

      /* See how many times the previous byte repeats */
      s.match_length = 0;
      if (s.lookahead >= MIN_MATCH && s.strstart > 0) {
        scan = s.strstart - 1;
        prev = _win[scan];
        if (prev == _win[++scan] && prev == _win[++scan] && prev == _win[++scan]) {
          strend = s.strstart + MAX_MATCH;
          do {
            /*jshint noempty:false*/
          } while (prev == _win[++scan] && prev == _win[++scan] &&
                   prev == _win[++scan] && prev == _win[++scan] &&
                   prev == _win[++scan] && prev == _win[++scan] &&
                   prev == _win[++scan] && prev == _win[++scan] &&
                   scan < strend);
          s.match_length = MAX_MATCH - (strend - scan);
          if (s.match_length > s.lookahead) {
            s.match_length = s.lookahead;
          }
        }
        //Assert(scan <= s->window+(uInt)(s->window_size-1), "wild scan");
      }

      /* Emit match if have run of MIN_MATCH or longer, else emit literal */
      if (s.match_length >= MIN_MATCH) {
        //check_match(s, s.strstart, s.strstart - 1, s.match_length);

        /*** _tr_tally_dist(s, 1, s.match_length - MIN_MATCH, bflush); ***/
        bflush = Trees._tr_tally(s, 1, s.match_length - MIN_MATCH);

        s.lookahead -= s.match_length;
        s.strstart += s.match_length;
        s.match_length = 0;
      } else {
        /* No match, output a literal byte */
        //Tracevv((stderr,"%c", s->window[s->strstart]));
        /*** _tr_tally_lit(s, s.window[s.strstart], bflush); ***/
        bflush = Trees._tr_tally(s, 0, s.window[s.strstart]);

        s.lookahead--;
        s.strstart++;
      }
      if (bflush) {
        /*** FLUSH_BLOCK(s, 0); ***/
        flush_block_only(s, false);
        if (s.strm.avail_out == 0) {
          return BS_NEED_MORE;
        }
        /***/
      }
    }
    s.insert = 0;
    if (flush == Flush.Z_FINISH) {
      /*** FLUSH_BLOCK(s, 1); ***/
      flush_block_only(s, true);
      if (s.strm.avail_out == 0) {
        return BS_FINISH_STARTED;
      }
      /***/
      return BS_FINISH_DONE;
    }
    if (s.last_lit != 0) {
      /*** FLUSH_BLOCK(s, 0); ***/
      flush_block_only(s, false);
      if (s.strm.avail_out == 0) {
        return BS_NEED_MORE;
      }
      /***/
    }
    return BS_BLOCK_DONE;
  }

  /* ===========================================================================
   * For Z_HUFFMAN_ONLY, do not look for matches.  Do not maintain a hash table.
   * (It will be regenerated if this run of deflate switches away from Huffman.)
   */
  static function deflate_huff(s:DeflateState, flush) {
    var bflush;             /* set if current block must be flushed */

    while (true) {
      /* Make sure that we have a literal to write. */
      if (s.lookahead == 0) {
        fill_window(s);
        if (s.lookahead == 0) {
          if (flush == Flush.Z_NO_FLUSH) {
            return BS_NEED_MORE;
          }
          break;      /* flush the current block */
        }
      }

      /* Output a literal byte */
      s.match_length = 0;
      //Tracevv((stderr,"%c", s->window[s->strstart]));
      /*** _tr_tally_lit(s, s.window[s.strstart], bflush); ***/
      bflush = Trees._tr_tally(s, 0, s.window[s.strstart]);
      s.lookahead--;
      s.strstart++;
      if (bflush) {
        /*** FLUSH_BLOCK(s, 0); ***/
        flush_block_only(s, false);
        if (s.strm.avail_out == 0) {
          return BS_NEED_MORE;
        }
        /***/
      }
    }
    s.insert = 0;
    if (flush == Flush.Z_FINISH) {
      /*** FLUSH_BLOCK(s, 1); ***/
      flush_block_only(s, true);
      if (s.strm.avail_out == 0) {
        return BS_FINISH_STARTED;
      }
      /***/
      return BS_FINISH_DONE;
    }
    if (s.last_lit != 0) {
      /*** FLUSH_BLOCK(s, 0); ***/
      flush_block_only(s, false);
      if (s.strm.avail_out == 0) {
        return BS_NEED_MORE;
      }
      /***/
    }
    return BS_BLOCK_DONE;
  }

  //NOTE(hx): Config moved to end of file
  
  static var configuration_table:Array<Config>;
  
  static function __init__() {
    configuration_table = [
      /*      good lazy nice chain */
      new Config(0, 0, 0, 0, deflate_stored),          /* 0 store only */
      new Config(4, 4, 8, 4, deflate_fast),            /* 1 max speed, no lazy matches */
      new Config(4, 5, 16, 8, deflate_fast),           /* 2 */
      new Config(4, 6, 32, 32, deflate_fast),          /* 3 */

      new Config(4, 4, 16, 16, deflate_slow),          /* 4 lazy matches */
      new Config(8, 16, 32, 32, deflate_slow),         /* 5 */
      new Config(8, 16, 128, 128, deflate_slow),       /* 6 */
      new Config(8, 32, 128, 256, deflate_slow),       /* 7 */
      new Config(32, 128, 258, 1024, deflate_slow),    /* 8 */
      new Config(32, 258, 258, 4096, deflate_slow)     /* 9 max compression */
    ];
  }
  

  /* ===========================================================================
   * Initialize the "longest match" routines for a new zlib stream
   */
  static function lm_init(s:DeflateState) {
    s.window_size = 2 * s.w_size;

    /*** CLEAR_HASH(s); ***/
    Common.zero(cast s.head); // Fill with NIL (= 0);

    /* Set the default configuration parameters:
     */
    s.max_lazy_match = configuration_table[s.level].max_lazy;
    s.good_match = configuration_table[s.level].good_length;
    s.nice_match = configuration_table[s.level].nice_length;
    s.max_chain_length = configuration_table[s.level].max_chain;

    s.strstart = 0;
    s.block_start = 0;
    s.lookahead = 0;
    s.insert = 0;
    s.match_length = s.prev_length = MIN_MATCH - 1;
    s.match_available = false;
    s.ins_h = 0;
  }

  //NOTE(hx): DeflateState moved to end of file


  static public function deflateResetKeep(strm:ZStream) {
    var s:DeflateState;

    if (strm == null || strm.deflateState == null) {
      return err(strm, ErrorStatus.Z_STREAM_ERROR);
    }

    strm.total_in = strm.total_out = 0;
    strm.data_type = DataType.Z_UNKNOWN;

    s = strm.deflateState;
    s.pending = 0;
    s.pending_out = 0;

    if (s.wrap < 0) {
      s.wrap = -s.wrap;
      /* was made negative by deflate(..., Z_FINISH); */
    }
    //NOTE(hx): check wrap to bool
    s.status = (s.wrap != 0 ? INIT_STATE : BUSY_STATE);
    strm.adler = (s.wrap == 2) ?
      0  // crc32(0, Z_NULL, 0)
    :
      1; // adler32(0, Z_NULL, 0)
    s.last_flush = Flush.Z_NO_FLUSH;
    Trees._tr_init(s);
    return ErrorStatus.Z_OK;
  }


  static public function deflateReset(strm:ZStream) {
    var ret = deflateResetKeep(strm);
    if (ret == ErrorStatus.Z_OK) {
      lm_init(strm.deflateState);
    }
    return ret;
  }


  static public function deflateSetHeader(?strm:ZStream, ?head) {
    if (strm == null || strm.deflateState == null) { return ErrorStatus.Z_STREAM_ERROR; }
    if (strm.deflateState.wrap != 2) { return ErrorStatus.Z_STREAM_ERROR; }
    strm.deflateState.gzhead = head;
    return ErrorStatus.Z_OK;
  }


  static public function deflateInit2(strm:ZStream, level:Int, method:Int, windowBits, memLevel, strategy:Int) {
    if (strm == null) { // == Z_NULL
      return ErrorStatus.Z_STREAM_ERROR;
    }
    var wrap = 1;

    if (level == CompressionLevel.Z_DEFAULT_COMPRESSION) {
      level = 6;
    }

    if (windowBits < 0) { /* suppress zlib wrapper */
      wrap = 0;
      windowBits = -windowBits;
    }

    else if (windowBits > 15) {
      wrap = 2;           /* write gzip wrapper instead */
      windowBits -= 16;
    }


    if (memLevel < 1 || memLevel > MAX_MEM_LEVEL || method != Method.Z_DEFLATED ||
      windowBits < 8 || windowBits > 15 || level < 0 || level > 9 ||
      strategy < 0 || strategy > Strategy.Z_FIXED) {
      return err(strm, ErrorStatus.Z_STREAM_ERROR);
    }


    if (windowBits == 8) {
      windowBits = 9;
    }
    /* until 256-byte window bug fixed */

    var s = new DeflateState();

    strm.deflateState = s;
    s.strm = strm;

    s.wrap = wrap;
    s.gzhead = null;
    s.w_bits = windowBits;
    s.w_size = 1 << s.w_bits;
    s.w_mask = s.w_size - 1;

    s.hash_bits = memLevel + 7;
    s.hash_size = 1 << s.hash_bits;
    s.hash_mask = s.hash_size - 1;
    //NOTE(hx): division
    s.hash_shift = ~(~Std.int((s.hash_bits + MIN_MATCH - 1) / MIN_MATCH));

    s.window = new UInt8Array(s.w_size * 2);
    s.head = new UInt16Array(s.hash_size);
    s.prev = new UInt16Array(s.w_size);

    // Don't need mem init magic for JS.
    //s.high_water = 0;  /* nothing written to s->window yet */

    s.lit_bufsize = 1 << (memLevel + 6); /* 16K elements by default */

    s.pending_buf_size = s.lit_bufsize * 4;
    s.pending_buf = new UInt8Array(s.pending_buf_size);

    s.d_buf = s.lit_bufsize >> 1;
    s.l_buf = (1 + 2) * s.lit_bufsize;

    s.level = level;
    s.strategy = strategy;
    s.method = method;

    return deflateReset(strm);
  }

  static inline public function deflateInit(?strm:ZStream, level:Int = CompressionLevel.Z_NO_COMPRESSION) {
    return deflateInit2(strm, level, Method.Z_DEFLATED, MAX_WBITS, DEF_MEM_LEVEL, Strategy.Z_DEFAULT_STRATEGY);
  }


  static public function deflate(strm:ZStream, flush:Int) {
    var old_flush, s:DeflateState;
    var beg, val; // for gzip header write only

    //NOTE(hx): chech flush
    if (strm == null || strm.deflateState == null ||
        flush > Flush.Z_BLOCK || flush < 0) {
      return strm != null ? err(strm, ErrorStatus.Z_STREAM_ERROR) : ErrorStatus.Z_STREAM_ERROR;
    }

    s = strm.deflateState;

    if (strm.output == null ||
        (strm.input == null && strm.avail_in != 0) ||
        (s.status == FINISH_STATE && flush != Flush.Z_FINISH)) {
      return err(strm, (strm.avail_out == 0) ? ErrorStatus.Z_BUF_ERROR : ErrorStatus.Z_STREAM_ERROR);
    }

    s.strm = strm; /* just in case */
    old_flush = s.last_flush;
    s.last_flush = flush;

    /* Write the header */
    if (s.status == INIT_STATE) {

      if (s.wrap == 2) { // GZIP header
        strm.adler = 0;  //crc32(0L, Z_NULL, 0);
        put_byte(s, 31);
        put_byte(s, 139);
        put_byte(s, 8);
        if (s.gzhead == null) { // s->gzhead == Z_NULL
          put_byte(s, 0);
          put_byte(s, 0);
          put_byte(s, 0);
          put_byte(s, 0);
          put_byte(s, 0);
          //NOTE(hx): 
          put_byte(s, s.level == 9 ? 2 :
                      (s.strategy >= Strategy.Z_HUFFMAN_ONLY || s.level < 2 ?
                       4 : 0));
          put_byte(s, OS_CODE);
          s.status = BUSY_STATE;
        }
        else {
          //NOTE(hx): check nulls and falsey values (and lengths)
          put_byte(s, (s.gzhead.text ? 1 : 0) +
                      (s.gzhead.hcrc != 0? 2 : 0) +
                      (s.gzhead.extra == null ? 0 : 4) +
                      (s.gzhead.name == null || s.gzhead.name == '' ? 0 : 8) +
                      (s.gzhead.comment == null || s.gzhead.comment == '' ? 0 : 16)
                  );
          put_byte(s, s.gzhead.time & 0xff);
          put_byte(s, (s.gzhead.time >> 8) & 0xff);
          put_byte(s, (s.gzhead.time >> 16) & 0xff);
          put_byte(s, (s.gzhead.time >> 24) & 0xff);
          put_byte(s, s.level == 9 ? 2 :
                      (s.strategy >= Strategy.Z_HUFFMAN_ONLY || s.level < 2 ?
                       4 : 0));
          put_byte(s, s.gzhead.os & 0xff);
          if (s.gzhead.extra != null && s.gzhead.extra.length > 0) {
            put_byte(s, s.gzhead.extra.length & 0xff);
            put_byte(s, (s.gzhead.extra.length >> 8) & 0xff);
          }
          if (s.gzhead.hcrc != 0) {
            strm.adler = CRC32.crc32(strm.adler, s.pending_buf, s.pending, 0);
          }
          s.gzindex = 0;
          s.status = EXTRA_STATE;
        }
      }
      else // DEFLATE header
      {
        var header = (Method.Z_DEFLATED + ((s.w_bits - 8) << 4)) << 8;
        var level_flags = -1;

        if (s.strategy >= Strategy.Z_HUFFMAN_ONLY || s.level < 2) {
          level_flags = 0;
        } else if (s.level < 6) {
          level_flags = 1;
        } else if (s.level == 6) {
          level_flags = 2;
        } else {
          level_flags = 3;
        }
        header |= (level_flags << 6);
        if (s.strstart != 0) { header |= PRESET_DICT; }
        header += 31 - (header % 31);

        s.status = BUSY_STATE;
        putShortMSB(s, header);

        /* Save the adler32 of the preset dictionary: */
        if (s.strstart != 0) {
          putShortMSB(s, strm.adler >>> 16);
          putShortMSB(s, strm.adler & 0xffff);
        }
        strm.adler = 1; // adler32(0L, Z_NULL, 0);
      }
    }

  //#ifdef GZIP
    if (s.status == EXTRA_STATE) {
      if (s.gzhead.extra != null/* != Z_NULL*/) {
        beg = s.pending;  /* start of bytes to update crc */

        while (s.gzindex < (s.gzhead.extra.length & 0xffff)) {
          if (s.pending == s.pending_buf_size) {
            if (s.gzhead.hcrc != 0 && s.pending > beg) {
              strm.adler = CRC32.crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
            }
            flush_pending(strm);
            beg = s.pending;
            if (s.pending == s.pending_buf_size) {
              break;
            }
          }
          put_byte(s, s.gzhead.extra[s.gzindex] & 0xff);
          s.gzindex++;
        }
        if (s.gzhead.hcrc != 0 && s.pending > beg) {
          strm.adler = CRC32.crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
        }
        if (s.gzindex == s.gzhead.extra.length) {
          s.gzindex = 0;
          s.status = NAME_STATE;
        }
      }
      else {
        s.status = NAME_STATE;
      }
    }
    if (s.status == NAME_STATE) {
      if (s.gzhead.name != null && s.gzhead.name != ''/* != Z_NULL*/) {
        beg = s.pending;  /* start of bytes to update crc */
        //int val;

        do {
          if (s.pending == s.pending_buf_size) {
            if (s.gzhead.hcrc != 0 && s.pending > beg) {
              strm.adler = CRC32.crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
            }
            flush_pending(strm);
            beg = s.pending;
            if (s.pending == s.pending_buf_size) {
              val = 1;
              break;
            }
          }
          // JS specific: little magic to add zero terminator to end of string
          if (s.gzindex < s.gzhead.name.length) {
            val = s.gzhead.name.charCodeAt(s.gzindex++) & 0xff;
          } else {
            val = 0;
          }
          put_byte(s, val);
        } while (val != 0);

        if (s.gzhead.hcrc != 0 && s.pending > beg) {
          strm.adler = CRC32.crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
        }
        if (val == 0) {
          s.gzindex = 0;
          s.status = COMMENT_STATE;
        }
      }
      else {
        s.status = COMMENT_STATE;
      }
    }
    if (s.status == COMMENT_STATE) {
      if (s.gzhead.comment != null && s.gzhead.comment != ''/* != Z_NULL*/) {
        beg = s.pending;  /* start of bytes to update crc */
        //int val;

        do {
          if (s.pending == s.pending_buf_size) {
            if (s.gzhead.hcrc != 0 && s.pending > beg) {
              strm.adler = CRC32.crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
            }
            flush_pending(strm);
            beg = s.pending;
            if (s.pending == s.pending_buf_size) {
              val = 1;
              break;
            }
          }
          // JS specific: little magic to add zero terminator to end of string
          if (s.gzindex < s.gzhead.comment.length) {
            val = s.gzhead.comment.charCodeAt(s.gzindex++) & 0xff;
          } else {
            val = 0;
          }
          put_byte(s, val);
        } while (val != 0);

        if (s.gzhead.hcrc != 0 && s.pending > beg) {
          strm.adler = CRC32.crc32(strm.adler, s.pending_buf, s.pending - beg, beg);
        }
        if (val == 0) {
          s.status = HCRC_STATE;
        }
      }
      else {
        s.status = HCRC_STATE;
      }
    }
    if (s.status == HCRC_STATE) {
      if (s.gzhead.hcrc != 0) {
        if (s.pending + 2 > s.pending_buf_size) {
          flush_pending(strm);
        }
        if (s.pending + 2 <= s.pending_buf_size) {
          put_byte(s, strm.adler & 0xff);
          put_byte(s, (strm.adler >> 8) & 0xff);
          strm.adler = 0; //crc32(0L, Z_NULL, 0);
          s.status = BUSY_STATE;
        }
      }
      else {
        s.status = BUSY_STATE;
      }
    }
  //#endif

    /* Flush as much pending output as possible */
    if (s.pending != 0) {
      flush_pending(strm);
      if (strm.avail_out == 0) {
        /* Since avail_out is 0, deflate will be called again with
         * more output space, but possibly with both pending and
         * avail_in equal to zero. There won't be anything to do,
         * but this is not an error situation so make sure we
         * return OK instead of BUF_ERROR at next call of deflate:
         */
        s.last_flush = -1;
        return ErrorStatus.Z_OK;
      }

      /* Make sure there is something to do and avoid duplicate consecutive
       * flushes. For repeated and useless calls with Z_FINISH, we keep
       * returning Z_STREAM_END instead of Z_BUF_ERROR.
       */
    } else if (strm.avail_in == 0 && rank(flush) <= rank(old_flush) &&
      flush != Flush.Z_FINISH) {
      return err(strm, ErrorStatus.Z_BUF_ERROR);
    }

    /* User must not provide more input after the first FINISH: */
    if (s.status == FINISH_STATE && strm.avail_in != 0) {
      return err(strm, ErrorStatus.Z_BUF_ERROR);
    }

    /* Start a new block or continue the current one.
     */
    if (strm.avail_in != 0 || s.lookahead != 0 ||
      (flush != Flush.Z_NO_FLUSH && s.status != FINISH_STATE)) {
      var bstate = (s.strategy == Strategy.Z_HUFFMAN_ONLY) ? deflate_huff(s, flush) :
        (s.strategy == Strategy.Z_RLE ? deflate_rle(s, flush) :
          configuration_table[s.level].func(s, flush));

      if (bstate == BS_FINISH_STARTED || bstate == BS_FINISH_DONE) {
        s.status = FINISH_STATE;
      }
      if (bstate == BS_NEED_MORE || bstate == BS_FINISH_STARTED) {
        if (strm.avail_out == 0) {
          s.last_flush = -1;
          /* avoid BUF_ERROR next call, see above */
        }
        return ErrorStatus.Z_OK;
        /* If flush != Z_NO_FLUSH && avail_out == 0, the next call
         * of deflate should use the same flush parameter to make sure
         * that the flush is complete. So we don't have to output an
         * empty block here, this will be done at next call. This also
         * ensures that for a very small output buffer, we emit at most
         * one empty block.
         */
      }
      if (bstate == BS_BLOCK_DONE) {
        if (flush == Flush.Z_PARTIAL_FLUSH) {
          Trees._tr_align(s);
        }
        else if (flush != Flush.Z_BLOCK) { /* FULL_FLUSH or SYNC_FLUSH */

          Trees._tr_stored_block(s, 0, 0, false);
          /* For a full flush, this empty block will be recognized
           * as a special marker by inflate_sync().
           */
          if (flush == Flush.Z_FULL_FLUSH) {
            /*** CLEAR_HASH(s); ***/             /* forget history */
            Common.zero(cast s.head); // Fill with NIL (= 0);

            if (s.lookahead == 0) {
              s.strstart = 0;
              s.block_start = 0;
              s.insert = 0;
            }
          }
        }
        flush_pending(strm);
        if (strm.avail_out == 0) {
          s.last_flush = -1; /* avoid BUF_ERROR at next call, see above */
          return ErrorStatus.Z_OK;
        }
      }
    }
    //Assert(strm->avail_out > 0, "bug2");
    //if (strm.avail_out <= 0) { throw new Error("bug2");}

    if (flush != Flush.Z_FINISH) { return ErrorStatus.Z_OK; }
    if (s.wrap <= 0) { return ErrorStatus.Z_STREAM_END; }

    /* Write the trailer */
    if (s.wrap == 2) {
      put_byte(s, strm.adler & 0xff);
      put_byte(s, (strm.adler >> 8) & 0xff);
      put_byte(s, (strm.adler >> 16) & 0xff);
      put_byte(s, (strm.adler >> 24) & 0xff);
      put_byte(s, strm.total_in & 0xff);
      put_byte(s, (strm.total_in >> 8) & 0xff);
      put_byte(s, (strm.total_in >> 16) & 0xff);
      put_byte(s, (strm.total_in >> 24) & 0xff);
    }
    else
    {
      putShortMSB(s, strm.adler >>> 16);
      putShortMSB(s, strm.adler & 0xffff);
    }

    flush_pending(strm);
    /* If avail_out is zero, the application will call deflate again
     * to flush the rest.
     */
    if (s.wrap > 0) { s.wrap = -s.wrap; }
    /* write the trailer only once! */
    return s.pending != 0 ? ErrorStatus.Z_OK : ErrorStatus.Z_STREAM_END;
  }

  static public function deflateEnd(strm:ZStream) {
    var status;

    if (strm == null/*== Z_NULL*/ || strm.deflateState == null/*== Z_NULL*/) {
      return ErrorStatus.Z_STREAM_ERROR;
    }

    status = strm.deflateState.status;
    if (status != INIT_STATE &&
      status != EXTRA_STATE &&
      status != NAME_STATE &&
      status != COMMENT_STATE &&
      status != HCRC_STATE &&
      status != BUSY_STATE &&
      status != FINISH_STATE
    ) {
      return err(strm, ErrorStatus.Z_STREAM_ERROR);
    }

    strm.deflateState = null;

    return status == BUSY_STATE ? err(strm, ErrorStatus.Z_DATA_ERROR) : ErrorStatus.Z_OK;
  }
  
  /* =========================================================================
   * Initializes the compression dictionary from the given byte
   * sequence without producing any compressed output.
   */
  static public function deflateSetDictionary(strm:ZStream, dictionary:UInt8Array) {
    var dictLength = dictionary.length;

    var s:DeflateState;
    var str, n:Int;
    var wrap:Int;
    var avail:Int;
    var next:Int;
    var input:UInt8Array;
    var tmpDict:UInt8Array;

    if (strm == null/*== Z_NULL*/ || strm.deflateState == null/*== Z_NULL*/) {
      return ErrorStatus.Z_STREAM_ERROR;
    }

    s = strm.deflateState;
    wrap = s.wrap;

    if (wrap == 2 || (wrap == 1 && s.status != INIT_STATE) || s.lookahead > 0) {
      return ErrorStatus.Z_STREAM_ERROR;
    }

    /* when using zlib wrappers, compute Adler-32 for provided dictionary */
    if (wrap == 1) {
      /* adler32(strm->adler, dictionary, dictLength); */
      strm.adler = Adler32.adler32(strm.adler, dictionary, dictLength, 0);
    }

    s.wrap = 0;   /* avoid computing Adler-32 in read_buf */

    /* if dictionary would fill window, just replace the history */
    if (dictLength >= s.w_size) {
      if (wrap == 0) {            /* already empty otherwise */
        /*** CLEAR_HASH(s); ***/
        Common.zero(cast s.head); // Fill with NIL (= 0);
        s.strstart = 0;
        s.block_start = 0;
        s.insert = 0;
      }
      /* use the tail */
      // dictionary = dictionary.slice(dictLength - s.w_size);
      tmpDict = new UInt8Array(s.w_size);
      Common.arraySet(cast tmpDict, cast dictionary, dictLength - s.w_size, s.w_size, 0);
      dictionary = tmpDict;
      dictLength = s.w_size;
    }
    /* insert dictionary into window and hash */
    avail = strm.avail_in;
    next = strm.next_in;
    input = strm.input;
    strm.avail_in = dictLength;
    strm.next_in = 0;
    strm.input = dictionary;
    fill_window(s);
    while (s.lookahead >= MIN_MATCH) {
      str = s.strstart;
      n = s.lookahead - (MIN_MATCH - 1);
      do {
        /* UPDATE_HASH(s, s->ins_h, s->window[str + MIN_MATCH-1]); */
        s.ins_h = ((s.ins_h << s.hash_shift) ^ s.window[str + MIN_MATCH - 1]) & s.hash_mask;

        s.prev[str & s.w_mask] = s.head[s.ins_h];

        s.head[s.ins_h] = str;
        str++;
      } while (--n != 0);
      s.strstart = str;
      s.lookahead = MIN_MATCH - 1;
      fill_window(s);
    }
    s.strstart += s.lookahead;
    s.block_start = s.strstart;
    s.insert = s.lookahead;
    s.lookahead = 0;
    s.match_length = s.prev_length = MIN_MATCH - 1;
    s.match_available = false;
    strm.next_in = next;
    strm.input = input;
    strm.avail_in = avail;
    s.wrap = wrap;
    return ErrorStatus.Z_OK;
  }

}


@:allow(pako.zlib.Trees)
@:allow(pako.zlib.Deflate)
@:access(pako.zlib.Deflate)
class DeflateState
{
  var strm:ZStream = null;            /* pointer back to this zlib stream */
  var status:Int = 0;            /* as the name implies */
  var pending_buf:UInt8Array = null;      /* output still pending */
  var pending_buf_size:Int = 0;  /* size of pending_buf */
  var pending_out:Int = 0;       /* next pending byte to output to the stream */
  var pending:Int = 0;           /* nb of bytes in the pending buffer */
  var wrap:Int = 0;              /* bit 0 true for zlib, bit 1 true for gzip */
  var gzhead:GZHeader = null;         /* gzip header information to write */
  var gzindex:Int = 0;           /* where in extra, name, or comment */
  var method:Int = Method.Z_DEFLATED; /* can only be DEFLATED */
  var last_flush:Int = -1;   /* value of flush param for previous deflate call */

  var w_size:Int = 0;  /* LZ77 window size (32K by default) */
  var w_bits:Int = 0;  /* log2(w_size)  (8..16) */
  var w_mask:Int = 0;  /* w_size - 1 */

  var window:UInt8Array = null;
  /* Sliding window. Input bytes are read into the second half of the window,
   * and move to the first half later to keep a dictionary of at least wSize
   * bytes. With this organization, matches are limited to a distance of
   * wSize-MAX_MATCH bytes, but this ensures that IO is always
   * performed with a length multiple of the block size.
   */

  var window_size:Int = 0;
  /* Actual size of window: 2*wSize, except when the user input buffer
   * is directly used as sliding window.
   */

  var prev:UInt16Array = null;
  /* Link to older string with same hash index. To limit the size of this
   * array to 64K, this link is maintained only for the last 32K strings.
   * An index in this array is thus a window index modulo 32K.
   */

  var head:UInt16Array = null;   /* Heads of the hash chains or NIL. */

  var ins_h:Int = 0;       /* hash index of string to be inserted */
  var hash_size:Int = 0;   /* number of elements in hash table */
  var hash_bits:Int = 0;   /* log2(hash_size) */
  var hash_mask:Int = 0;   /* hash_size-1 */

  var hash_shift:Int = 0;
  /* Number of bits by which ins_h must be shifted at each input
   * step. It must be such that after MIN_MATCH steps, the oldest
   * byte no longer takes part in the hash key, that is:
   *   hash_shift * MIN_MATCH >= hash_bits
   */

  var block_start:Int = 0;
  /* Window position at the beginning of the current output block. Gets
   * negative when the window is moved backwards.
   */

  var match_length:Int = 0;      /* length of best match */
  var prev_match:Int = 0;        /* previous match */
  var match_available:Bool = false;   /* set if previous match exists */
  var strstart:Int = 0;          /* start of string to insert */
  var match_start:Int = 0;       /* start of matching string */
  var lookahead:Int = 0;         /* number of valid bytes ahead in window */

  var prev_length:Int = 0;
  /* Length of the best match at previous step. Matches not greater than this
   * are discarded. This is used in the lazy match evaluation.
   */

  var max_chain_length:Int = 0;
  /* To speed up deflation, hash chains are never searched beyond this
   * length.  A higher limit improves compression ratio but degrades the
   * speed.
   */

  var max_lazy_match:Int = 0;
  /* Attempt to find a better match only when the current match is strictly
   * smaller than this value. This mechanism is used only for compression
   * levels >= 4.
   */
  // That's alias to max_lazy_match, don't use directly
  //var max_insert_length = 0;
  /* Insert new strings in the hash table only if the match length is not
   * greater than this length. This saves time but degrades compression.
   * max_insert_length is used only for compression levels <= 3.
   */
  
  var level:Int = CompressionLevel.Z_NO_COMPRESSION;     /* compression level (1..9) */
  var strategy:Int = Strategy.Z_DEFAULT_STRATEGY;  /* favor or force Huffman coding*/

  var good_match:Int = 0;
  /* Use a faster search when the previous match is longer than this */

  var nice_match:Int = 0; /* Stop searching when current match exceeds this */

              /* used by trees.c: */

  /* Didn't use ct_data typedef below to suppress compiler warning */

  // struct ct_data_s dyn_ltree[HEAP_SIZE];   /* literal and length tree */
  // struct ct_data_s dyn_dtree[2*D_CODES+1]; /* distance tree */
  // struct ct_data_s bl_tree[2*BL_CODES+1];  /* Huffman tree for bit lengths */

  // Use flat array of DOUBLE size, with interleaved fata,
  // because JS does not support effective
  var dyn_ltree  = new UInt16Array(Deflate.HEAP_SIZE * 2);
  var dyn_dtree  = new UInt16Array((2*Deflate.D_CODES+1) * 2);
  var bl_tree    = new UInt16Array((2*Deflate.BL_CODES+1) * 2);

  var l_desc:TreeDesc   = null;         /* desc. for literal tree */
  var d_desc:TreeDesc   = null;         /* desc. for distance tree */
  var bl_desc:TreeDesc  = null;         /* desc. for bit length tree */

  //ush bl_count[MAX_BITS+1];
  var bl_count = new UInt16Array(Deflate.MAX_BITS+1);
  /* number of codes at each bit length for an optimal tree */

  //int heap[2*L_CODES+1];      /* heap used to build the Huffman trees */
  var heap = new UInt16Array(2*Deflate.L_CODES+1);  /* heap used to build the Huffman trees */

  var heap_len:Int = 0;               /* number of elements in the heap */
  var heap_max:Int = 0;               /* element of largest frequency */
  /* The sons of heap[n] are heap[2*n] and heap[2*n+1]. heap[0] is not used.
   * The same heap array is used to build all trees.
   */

  var depth = new UInt16Array(2*Deflate.L_CODES+1); //uch depth[2*L_CODES+1];
  /* Depth of each subtree used as tie breaker for trees of equal frequency
   */

  var l_buf:Int = 0;          /* buffer index for literals or lengths */

  var lit_bufsize:Int = 0;
  /* Size of match buffer for literals/lengths.  There are 4 reasons for
   * limiting lit_bufsize to 64K:
   *   - frequencies can be kept in 16 bit counters
   *   - if compression is not successful for the first block, all input
   *     data is still in the window so we can still emit a stored block even
   *     when input comes from standard input.  (This can also be done for
   *     all blocks if lit_bufsize is not greater than 32K.)
   *   - if compression is not successful for a file smaller than 64K, we can
   *     even emit a stored file instead of a stored block (saving 5 bytes).
   *     This is applicable only for zip (not gzip or zlib).
   *   - creating new Huffman trees less frequently may not provide fast
   *     adaptation to changes in the input data statistics. (Take for
   *     example a binary file with poorly compressible code followed by
   *     a highly compressible string table.) Smaller buffer sizes give
   *     fast adaptation but have of course the overhead of transmitting
   *     trees more frequently.
   *   - I can't count above 4
   */

  var last_lit:Int = 0;      /* running index in l_buf */

  var d_buf:Int = 0;
  /* Buffer index for distances. To simplify the code, d_buf and l_buf have
   * the same number of elements. To use different lengths, an extra flag
   * array would be necessary.
   */

  var opt_len:Int = 0;       /* bit length of current block with optimal trees */
  var static_len:Int = 0;    /* bit length of current block with static trees */
  var matches:Int = 0;       /* number of string matches in current block */
  var insert:Int = 0;        /* bytes at end of window left to insert */


  var bi_buf:Int = 0;
  /* Output buffer. bits are inserted starting at the bottom (least
   * significant bits).
   */
  var bi_valid:Int = 0;
  
  // Used for window memory init. We safely ignore it for JS. That makes
  // sense only for pointers and memory check tools.
  //this.high_water:Int = 0;
  /* High water mark offset in window for initialized bytes -- bytes above
   * this are set to zero in order to avoid memory check warnings when
   * longest match routines access bytes past the input.  This is then
   * updated to the new high water mark.
   */

  
  function new() {
    Common.zero(cast dyn_ltree);
    Common.zero(cast dyn_dtree);
    Common.zero(cast bl_tree);
    
    Common.zero(cast this.heap);
    
    Common.zero(cast this.depth);
  }
}

/* Values for max_lazy_match, good_match and max_chain_length, depending on
 * the desired pack level (0..9). The values given below have been tuned to
 * exclude worst case performance for pathological files. Better values may be
 * found for specific files.
 */
@:allow(pako.zlib.Deflate)
class Config 
{
  var good_length:Int;
  var max_lazy:Int;
  var nice_length:Int;
  var max_chain:Int;
  var func:DeflateState->Int->Int;

  function new(good_length, max_lazy, nice_length, max_chain, func:DeflateState->Int->Int) {
    this.good_length = good_length;
    this.max_lazy = max_lazy;
    this.nice_length = nice_length;
    this.max_chain = max_chain;
    this.func = func;
  }
}

/*
exports.deflateInit = deflateInit;
exports.deflateInit2 = deflateInit2;
exports.deflateReset = deflateReset;
exports.deflateResetKeep = deflateResetKeep;
exports.deflateSetHeader = deflateSetHeader;
exports.deflate = deflate;
exports.deflateEnd = deflateEnd;
exports.deflateSetDictionary = deflateSetDictionary;
exports.deflateInfo = 'pako deflate (from Nodeca project)';
*/

/* Not implemented
exports.deflateBound = deflateBound;
exports.deflateCopy = deflateCopy;
exports.deflateParams = deflateParams;
exports.deflatePending = deflatePending;
exports.deflatePrime = deflatePrime;
exports.deflateTune = deflateTune;
*/
