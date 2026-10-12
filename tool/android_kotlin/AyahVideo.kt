package com.alhuda.islamic.app

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.graphics.BitmapFactory
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * The ayah video: still frames drawn by Flutter (PNG) over the recitation,
 * encoded on the phone with the hardware H.264 and AAC encoders into an MP4
 * that WhatsApp, Instagram and Facebook stories accept.
 *
 * A segment is one recitation file (an ayah) or a silence, and the frames
 * shown during it; a long ayah has several frames, each shown for a share of
 * the time that matches its length (its weight).
 */
class AyahVideo(private val onProgress: (Double) -> Unit) {

    class Shot(val image: String, val weight: Double)
    class Segment(val audio: String?, val silenceMs: Long, val shots: List<Shot>)

    private class Sample(val data: ByteArray, val ptsUs: Long, val flags: Int)

    companion object {
        private const val RATE = 44100
        private const val CHANNELS = 2
        private const val TIMEOUT = 10_000L

        /** The largest story size the phone's encoder takes: 1080x1920, else 720x1280. */
        fun supportedSize(): IntArray {
            for (size in listOf(intArrayOf(1080, 1920), intArrayOf(720, 1280))) {
                if (encoderSupports(size[0], size[1])) return size
            }
            return intArrayOf(720, 1280)
        }

        private fun encoderSupports(w: Int, h: Int): Boolean {
            return try {
                MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
                    info.isEncoder && info.supportedTypes.any { it.equals("video/avc", true) } &&
                        info.getCapabilitiesForType("video/avc").videoCapabilities.isSizeSupported(w, h)
                }
            } catch (e: Exception) {
                false
            }
        }

        @Suppress("UNCHECKED_CAST")
        fun parse(raw: List<Map<String, Any?>>): List<Segment> = raw.map { s ->
            val shots = (s["shots"] as List<Map<String, Any?>>).map { Shot(it["image"] as String, (it["weight"] as Number).toDouble()) }
            Segment(s["audio"] as String?, (s["silenceMs"] as Number?)?.toLong() ?: 0L, shots)
        }

        // ------------------------------------------------------- sharing ---

        fun uriFor(context: Context, path: String): Uri =
            Uri.parse("content://${context.packageName}.videos/${Uri.encode(File(path).name)}")

        /** Opens [pkg] (WhatsApp, Instagram, Facebook) with the video; false when it is not installed. */
        fun shareTo(context: Context, path: String, pkg: String?, text: String): Boolean {
            val uri = uriFor(context, path)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "video/mp4"
                putExtra(Intent.EXTRA_STREAM, uri)
                if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            return try {
                if (pkg == null) {
                    context.startActivity(Intent.createChooser(send, "مشاركة الفيديو").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                } else {
                    send.setPackage(pkg)
                    context.grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    context.startActivity(send)
                }
                true
            } catch (e: Exception) {
                false
            }
        }

        /** Copies the video to the gallery (Movies/الهدى). Android 10+. */
        fun saveToGallery(context: Context, path: String): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
            return try {
                val values = ContentValues().apply {
                    put(MediaStore.Video.Media.DISPLAY_NAME, File(path).name)
                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/الهدى")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
                val resolver = context.contentResolver
                val uri = resolver.insert(MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values)
                    ?: return false
                resolver.openOutputStream(uri)?.use { out -> FileInputStream(path).use { it.copyTo(out) } } ?: return false
                values.clear()
                values.put(MediaStore.Video.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                true
            } catch (e: Exception) {
                false
            }
        }

        /** The clip's first picture as a JPEG at [out], for the preview; false when it cannot be read. */
        fun thumbnail(path: String, out: String): Boolean = try {
            val r = android.media.MediaMetadataRetriever()
            r.setDataSource(path)
            val bmp = r.getFrameAtTime(0, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            r.release()
            if (bmp == null) false else {
                java.io.FileOutputStream(out).use { bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 88, it) }
                bmp.recycle()
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    // ------------------------------------------------------------ render ---

    /** Writes the MP4 to [out]; returns its length in milliseconds. */
    fun render(segments: List<Segment>, width: Int, height: Int, fps: Int, out: String, background: String? = null): Long {
        // A clip from the phone behind the words: opened first so a file it
        // cannot read fails before any work.
        val clip = background?.let { BackgroundClip(it, width, height) }
        try {
            return renderInto(segments, width, height, fps, out, clip)
        } finally {
            clip?.release()
        }
    }

    private fun renderInto(segments: List<Segment>, width: Int, height: Int, fps: Int, out: String, clip: BackgroundClip?): Long {
        // 1. The sound: every recitation decoded, brought to 44.1 kHz stereo
        //    and encoded to AAC. Each segment's exact length comes from it.
        val audio = AudioTrackBuilder()
        val durations = LongArray(segments.size)
        segments.forEachIndexed { i, seg ->
            val before = audio.framesWritten
            if (seg.audio != null) audio.addFile(seg.audio)
            if (seg.silenceMs > 0) audio.addSilence(seg.silenceMs)
            durations[i] = (audio.framesWritten - before) * 1_000_000L / RATE
            onProgress(0.3 * (i + 1) / segments.size)
        }
        audio.finish()
        val totalUs = durations.sum()

        // 2. The picture timeline.
        class Span(val image: String, val startUs: Long, val endUs: Long)
        val spans = ArrayList<Span>()
        var t = 0L
        segments.forEachIndexed { i, seg ->
            val sum = seg.shots.sumOf { it.weight }.coerceAtLeast(1e-9)
            var at = t
            seg.shots.forEachIndexed { k, shot ->
                val end = if (k == seg.shots.size - 1) t + durations[i] else at + (durations[i] * shot.weight / sum).toLong()
                spans.add(Span(shot.image, at, end))
                at = end
            }
            t += durations[i]
        }

        // 3. The video, muxed with the sound as it goes.
        val format = MediaFormat.createVideoFormat("video/avc", width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, if (width >= 1080) 3_500_000 else 2_200_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
            setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
            setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        }
        val encoder = MediaCodec.createEncoderByType("video/avc")
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()
        File(out).delete()
        val muxer = MediaMuxer(out, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var videoTrack = -1
        var audioTrack = -1
        var audioNext = 0
        val info = MediaCodec.BufferInfo()

        fun writeAudioUpTo(ptsUs: Long) {
            while (audioNext < audio.samples.size && audio.samples[audioNext].ptsUs <= ptsUs) {
                val s = audio.samples[audioNext++]
                val bi = MediaCodec.BufferInfo().apply { set(0, s.data.size, s.ptsUs, s.flags) }
                muxer.writeSampleData(audioTrack, ByteBuffer.wrap(s.data), bi)
            }
        }

        fun drain(endOfStream: Boolean) {
            while (true) {
                val idx = encoder.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT else 0)
                when {
                    idx == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!endOfStream) return
                    idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        videoTrack = muxer.addTrack(encoder.outputFormat)
                        audioTrack = muxer.addTrack(audio.format!!)
                        muxer.start()
                    }
                    idx >= 0 -> {
                        val buf = encoder.getOutputBuffer(idx)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0 && videoTrack >= 0) {
                            buf.position(info.offset)
                            buf.limit(info.offset + info.size)
                            muxer.writeSampleData(videoTrack, buf, info)
                            writeAudioUpTo(info.presentationTimeUs)
                        }
                        encoder.releaseOutputBuffer(idx, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }

        val frameUs = 1_000_000L / fps
        val fade = 350_000L // a soft crossfade between frames
        val frames = ((totalUs + frameUs - 1) / frameUs).toInt().coerceAtLeast(1)
        val cache = LinkedHashMap<String, ByteArray>()
        val overlays = LinkedHashMap<String, Overlay>()
        val mixed = ByteArray(width * height * 3 / 2)
        val composed = ByteArray(width * height * 3 / 2)
        val composedPrev = if (clip != null) ByteArray(width * height * 3 / 2) else composed
        fun yuv(path: String): ByteArray = cache.getOrPut(path) {
            if (cache.size > 3) cache.remove(cache.keys.first())
            toI420(path, width, height)
        }
        fun overlay(path: String): Overlay = overlays.getOrPut(path) {
            if (overlays.size > 2) overlays.remove(overlays.keys.first())
            Overlay(path, width, height)
        }
        var span = 0
        for (f in 0 until frames) {
            val pts = f * frameUs
            while (span < spans.size - 1 && pts >= spans[span].endUs) span++
            val into = pts - spans[span].startUs
            val fading = span > 0 && into < fade && spans[span - 1].image != spans[span].image
            val k = (into * 256 / fade).toInt().coerceIn(0, 256)
            val frame = if (clip != null) {
                // The clip's frame at this moment, the words drawn over it.
                clip.frameAt(pts)
                overlay(spans[span].image).over(clip, composed)
                if (fading) {
                    overlay(spans[span - 1].image).over(clip, composedPrev)
                    for (i in mixed.indices) mixed[i] = (((composedPrev[i].toInt() and 255) * (256 - k) + (composed[i].toInt() and 255) * k) shr 8).toByte()
                    mixed
                } else composed
            } else {
                val cur = yuv(spans[span].image)
                if (fading) {
                    val prev = yuv(spans[span - 1].image)
                    for (i in mixed.indices) mixed[i] = (((prev[i].toInt() and 255) * (256 - k) + (cur[i].toInt() and 255) * k) shr 8).toByte()
                    mixed
                } else cur
            }
            var idx: Int
            do {
                idx = encoder.dequeueInputBuffer(TIMEOUT)
                if (idx < 0) drain(false)
            } while (idx < 0)
            val image = encoder.getInputImage(idx)
            if (image != null) {
                fill(image, frame, width, height)
            } else {
                val buf = encoder.getInputBuffer(idx)!!
                buf.clear()
                buf.put(frame, 0, minOf(frame.size, buf.remaining()))
            }
            encoder.queueInputBuffer(idx, 0, frame.size, pts, 0)
            drain(false)
            if (f % 10 == 0) onProgress(0.3 + 0.7 * f / frames)
        }
        var idx: Int
        do {
            idx = encoder.dequeueInputBuffer(TIMEOUT)
            if (idx < 0) drain(false)
        } while (idx < 0)
        encoder.queueInputBuffer(idx, 0, 0, frames * frameUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(true)
        if (audioTrack >= 0) writeAudioUpTo(Long.MAX_VALUE)
        encoder.stop()
        encoder.release()
        muxer.stop()
        muxer.release()
        onProgress(1.0)
        return totalUs / 1000
    }

    /** A PNG to I420 (BT.709, limited range), averaged over each 2x2 block for the colour. */
    private fun toI420(path: String, w: Int, h: Int): ByteArray {
        var bmp = BitmapFactory.decodeFile(path) ?: throw IllegalStateException("frame not readable: $path")
        if (bmp.width != w || bmp.height != h) bmp = android.graphics.Bitmap.createScaledBitmap(bmp, w, h, true)
        val px = IntArray(w * h)
        bmp.getPixels(px, 0, w, 0, 0, w, h)
        bmp.recycle()
        val out = ByteArray(w * h * 3 / 2)
        for (i in px.indices) {
            val c = px[i]
            val r = (c shr 16) and 255; val g = (c shr 8) and 255; val b = c and 255
            out[i] = (((47 * r + 157 * g + 16 * b + 128) shr 8) + 16).toByte()
        }
        val cw = w / 2; val ch = h / 2
        val uOff = w * h; val vOff = uOff + cw * ch
        for (y in 0 until ch) for (x in 0 until cw) {
            var r = 0; var g = 0; var b = 0
            for (dy in 0..1) for (dx in 0..1) {
                val c = px[(2 * y + dy) * w + 2 * x + dx]
                r += (c shr 16) and 255; g += (c shr 8) and 255; b += c and 255
            }
            r /= 4; g /= 4; b /= 4
            out[uOff + y * cw + x] = (((-26 * r - 87 * g + 112 * b + 128) shr 8) + 128).toByte()
            out[vOff + y * cw + x] = (((112 * r - 102 * g - 10 * b + 128) shr 8) + 128).toByte()
        }
        return out
    }

    /** Copies an I420 frame into the encoder's own layout (planar or semi-planar). */
    private fun fill(image: Image, src: ByteArray, w: Int, h: Int) {
        val planes = image.planes
        val cw = w / 2; val ch = h / 2
        putPlane(planes[0], src, 0, w, h)
        putPlane(planes[1], src, w * h, cw, ch)
        putPlane(planes[2], src, w * h + cw * ch, cw, ch)
    }

    private fun putPlane(plane: Image.Plane, src: ByteArray, offset: Int, w: Int, h: Int) {
        val buf = plane.buffer
        val rs = plane.rowStride
        val ps = plane.pixelStride
        if (ps == 1) {
            if (rs == w) {
                buf.position(0)
                buf.put(src, offset, w * h)
            } else {
                for (row in 0 until h) {
                    buf.position(row * rs)
                    buf.put(src, offset + row * w, w)
                }
            }
        } else {
            for (row in 0 until h) {
                val base = row * rs
                val s = offset + row * w
                for (col in 0 until w) buf.put(base + col * ps, src[s + col])
            }
        }
    }

    // -------------------------------------------------- background clip ---

    /**
     * A frame drawn by Flutter with a see-through background (the words and a
     * dark veil), kept as luma/chroma already multiplied by its alpha so laying
     * it over the clip is one multiply-add a pixel.
     */
    private class Overlay(path: String, w: Int, h: Int) {
        val y = ShortArray(w * h) // alpha * Y (0..255*256)
        val ya = ShortArray(w * h) // 256 - alpha, what is left of the clip
        val u = ShortArray(w * h / 4)
        val v = ShortArray(w * h / 4)
        val ca = ShortArray(w * h / 4)

        init {
            var bmp = BitmapFactory.decodeFile(path) ?: throw IllegalStateException("frame not readable: $path")
            if (bmp.width != w || bmp.height != h) bmp = android.graphics.Bitmap.createScaledBitmap(bmp, w, h, true)
            val px = IntArray(w * h)
            bmp.getPixels(px, 0, w, 0, 0, w, h) // not premultiplied
            bmp.recycle()
            for (i in px.indices) {
                val c = px[i]
                val a = ((c ushr 24) and 255).let { it + (it shr 7) } // 0..256
                val r = (c shr 16) and 255; val g = (c shr 8) and 255; val b = c and 255
                val luma = ((47 * r + 157 * g + 16 * b + 128) shr 8) + 16
                y[i] = (luma * a).toShort()
                ya[i] = (256 - a).toShort()
            }
            val cw = w / 2; val ch = h / 2
            for (yy in 0 until ch) for (xx in 0 until cw) {
                var r = 0; var g = 0; var b = 0; var a = 0
                for (dy in 0..1) for (dx in 0..1) {
                    val c = px[(2 * yy + dy) * w + 2 * xx + dx]
                    val al = (c ushr 24) and 255
                    r += ((c shr 16) and 255) * al; g += ((c shr 8) and 255) * al; b += (c and 255) * al; a += al
                }
                val o = yy * cw + xx
                val a256 = (a / 4).let { it + (it shr 7) }
                if (a == 0) {
                    u[o] = 0; v[o] = 0; ca[o] = 256
                    continue
                }
                r /= a; g /= a; b /= a // the colour where it is drawn
                val uu = ((-26 * r - 87 * g + 112 * b + 128) shr 8) + 128
                val vv = ((112 * r - 102 * g - 10 * b + 128) shr 8) + 128
                u[o] = (uu * a256).toShort(); v[o] = (vv * a256).toShort(); ca[o] = (256 - a256).toShort()
            }
        }

        /** This frame over the clip's current picture, as I420 into [out]. */
        fun over(clip: BackgroundClip, out: ByteArray) {
            val by = clip.y; val bu = clip.u; val bv = clip.v
            for (i in by.indices) {
                out[i] = (((y[i].toInt() and 0xFFFF) + (by[i].toInt() and 255) * ya[i]) shr 8).toByte()
            }
            val n = bu.size
            val uOff = by.size; val vOff = uOff + n
            for (i in 0 until n) {
                val left = ca[i].toInt()
                out[uOff + i] = (((u[i].toInt() and 0xFFFF) + (bu[i].toInt() and 255) * left) shr 8).toByte()
                out[vOff + i] = (((v[i].toInt() and 0xFFFF) + (bv[i].toInt() and 255) * left) shr 8).toByte()
            }
        }
    }

    /**
     * The user's own video behind the words: decoded frame by frame, scaled to
     * cover the story (turned the way the phone filmed it) and looped when the
     * recitation is longer than it. Silent: only the recitation is heard.
     */
    class BackgroundClip(path: String, private val w: Int, private val h: Int) {
        val y = ByteArray(w * h)
        val u = ByteArray(w * h / 4)
        val v = ByteArray(w * h / 4)

        private val extractor = MediaExtractor()
        private val decoder: MediaCodec
        private val rotation: Int
        private val frameUs: Long
        private val info = MediaCodec.BufferInfo()
        private var inputDone = false
        private var have = false
        private var pending = -1
        private var pendingPts = 0L
        private var lastPts = 0L
        private var loopOffset = 0L
        private var decodedThisLoop = 0
        private var finished = false // nothing more can be decoded: the last picture stays

        // Where each output pixel reads from, split per column and per row.
        private var mapKey = ""
        private var colY = IntArray(0); private var rowY = IntArray(0)
        private var colC = IntArray(0); private var rowC = IntArray(0)
        private var py = ByteArray(0); private var pu = ByteArray(0); private var pv = ByteArray(0)

        init {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
            } ?: throw IllegalStateException("no video track")
            extractor.selectTrack(track)
            val fmt = extractor.getTrackFormat(track)
            rotation = readRotation(path, fmt)
            val rate = try {
                if (fmt.containsKey(MediaFormat.KEY_FRAME_RATE)) fmt.getInteger(MediaFormat.KEY_FRAME_RATE) else 30
            } catch (e: Exception) {
                try { fmt.getFloat(MediaFormat.KEY_FRAME_RATE).toInt() } catch (e2: Exception) { 30 }
            }
            frameUs = 1_000_000L / rate.coerceIn(1, 120)
            decoder = MediaCodec.createDecoderByType(fmt.getString(MediaFormat.KEY_MIME)!!)
            fmt.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            decoder.configure(fmt, null, null, 0)
            decoder.start()
            // Darkness until the first frame arrives (and the first frame now,
            // so an unreadable clip fails at once).
            java.util.Arrays.fill(y, 16.toByte()); java.util.Arrays.fill(u, 128.toByte()); java.util.Arrays.fill(v, 128.toByte())
            frameAt(0)
        }

        private fun readRotation(path: String, fmt: MediaFormat): Int {
            if (fmt.containsKey("rotation-degrees")) return ((fmt.getInteger("rotation-degrees") % 360) + 360) % 360
            return try {
                val r = android.media.MediaMetadataRetriever()
                r.setDataSource(path)
                val d = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
                r.release()
                ((d % 360) + 360) % 360
            } catch (e: Exception) {
                0
            }
        }

        /** Brings [y]/[u]/[v] to the clip's picture at [ptsUs] of the video. */
        fun frameAt(ptsUs: Long) {
            if (finished) return
            var idle = 0
            while (true) {
                if (pending >= 0) {
                    if (!have || pendingPts + loopOffset <= ptsUs) {
                        // A picture the next one replaces before it is shown is not copied.
                        val shown = !have || pendingPts + loopOffset + frameUs > ptsUs
                        if (shown) decoder.getOutputImage(pending)?.let { take(it) }
                        decoder.releaseOutputBuffer(pending, false)
                        pending = -1
                        have = true
                        continue
                    }
                    return
                }
                if (!inputDone) {
                    val inIdx = decoder.dequeueInputBuffer(0)
                    if (inIdx >= 0) {
                        val buf = decoder.getInputBuffer(inIdx)!!
                        val n = extractor.readSampleData(buf, 0)
                        if (n < 0) {
                            decoder.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inIdx, 0, n, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val idx = decoder.dequeueOutputBuffer(info, TIMEOUT)
                if (idx >= 0) {
                    idle = 0
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        decoder.releaseOutputBuffer(idx, false)
                        if (decodedThisLoop == 0) {
                            if (!have) throw IllegalStateException("clip has no frames")
                            finished = true
                            return // nothing more to show: keep the last picture
                        }
                        // Again from the start, after the last frame's time.
                        loopOffset += lastPts + frameUs
                        lastPts = 0
                        decodedThisLoop = 0
                        extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                        decoder.flush()
                        inputDone = false
                        continue
                    }
                    if (info.size <= 0) {
                        decoder.releaseOutputBuffer(idx, false)
                        continue
                    }
                    pending = idx
                    pendingPts = info.presentationTimeUs
                    lastPts = maxOf(lastPts, pendingPts)
                    decodedThisLoop++
                } else if (idx == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (++idle > 300) {
                        if (have) { finished = true; return }
                        throw IllegalStateException("clip decoder stalled")
                    }
                }
            }
        }

        /** Copies one decoded picture, cropped to fill the story, into [y]/[u]/[v]. */
        private fun take(image: Image) {
            val crop = image.cropRect
            val planes = image.planes
            val key = "${crop.left},${crop.top},${crop.width()},${crop.height()},${planes[0].rowStride},${planes[0].pixelStride}," +
                "${planes[1].rowStride},${planes[1].pixelStride}"
            if (key != mapKey) buildMaps(crop.left, crop.top, crop.width(), crop.height(), planes)
            mapKey = key
            py = copy(planes[0].buffer, py)
            pu = copy(planes[1].buffer, pu)
            pv = copy(planes[2].buffer, pv)
            val yLimit = py.size - 1
            for (yy in 0 until h) {
                val r = rowY[yy]; val o = yy * w
                for (xx in 0 until w) y[o + xx] = py[minOf(r + colY[xx], yLimit)]
            }
            val cw = w / 2; val ch = h / 2
            val uLimit = pu.size - 1; val vLimit = pv.size - 1
            for (yy in 0 until ch) {
                val r = rowC[yy]; val o = yy * cw
                for (xx in 0 until cw) {
                    val s = r + colC[xx]
                    u[o + xx] = pu[minOf(s, uLimit)]
                    v[o + xx] = pv[minOf(s, vLimit)]
                }
            }
        }

        private fun copy(buf: ByteBuffer, into: ByteArray): ByteArray {
            val b = buf.duplicate()
            b.position(0)
            val n = b.remaining()
            val arr = if (into.size == n) into else ByteArray(n)
            b.get(arr, 0, n)
            return arr
        }

        private fun buildMaps(left: Int, top: Int, cw: Int, ch: Int, planes: Array<Image.Plane>) {
            val turned = rotation == 90 || rotation == 270
            val dispW = if (turned) ch else cw
            val dispH = if (turned) cw else ch
            val scale = maxOf(w.toDouble() / dispW, h.toDouble() / dispH)
            val x0 = (dispW - w / scale) / 2
            val y0 = (dispH - h / scale) / 2
            fun dx(x: Int) = (x0 + (x + 0.5) / scale).toInt().coerceIn(0, dispW - 1)
            fun dy(y: Int) = (y0 + (y + 0.5) / scale).toInt().coerceIn(0, dispH - 1)
            // Display point -> stored point, by how the phone was held.
            fun src(px: Int, py: Int): IntArray = when (rotation) {
                90 -> intArrayOf(py, ch - 1 - px)
                180 -> intArrayOf(cw - 1 - px, ch - 1 - py)
                270 -> intArrayOf(cw - 1 - py, px)
                else -> intArrayOf(px, py)
            }
            val rsY = planes[0].rowStride; val psY = planes[0].pixelStride
            val rsC = planes[1].rowStride; val psC = planes[1].pixelStride
            fun idxY(px: Int, py: Int): Int { val s = src(px, py); return (top + s[1]) * rsY + (left + s[0]) * psY }
            fun idxC(px: Int, py: Int): Int { val s = src(px, py); return ((top + s[1]) / 2) * rsC + ((left + s[0]) / 2) * psC }
            // Each stored coordinate follows one display coordinate only, so a
            // pixel's index is a column part plus a row part.
            val y00 = idxY(0, 0); val c00 = idxC(0, 0)
            colY = IntArray(w) { idxY(dx(it), 0) }
            rowY = IntArray(h) { idxY(0, dy(it)) - y00 }
            colC = IntArray(w / 2) { idxC(dx(2 * it), 0) }
            rowC = IntArray(h / 2) { idxC(0, dy(2 * it)) - c00 }
        }

        fun release() {
            try { decoder.stop() } catch (e: Exception) {}
            try { decoder.release() } catch (e: Exception) {}
            try { extractor.release() } catch (e: Exception) {}
        }
    }

    // ------------------------------------------------------------- sound ---

    private inner class AudioTrackBuilder {
        val samples = ArrayList<Sample>()
        var format: MediaFormat? = null
        var framesWritten = 0L
        private val encoder: MediaCodec = MediaCodec.createEncoderByType("audio/mp4a-latm").apply {
            val f = MediaFormat.createAudioFormat("audio/mp4a-latm", RATE, CHANNELS).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            }
            configure(f, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            start()
        }
        private val info = MediaCodec.BufferInfo()

        fun addSilence(ms: Long) {
            val frames = ms * RATE / 1000
            val chunk = ByteArray(4096)
            var left = frames * CHANNELS * 2
            while (left > 0) {
                val n = minOf(left, chunk.size.toLong()).toInt()
                feed(chunk, n)
                left -= n
            }
        }

        /** Decodes one recitation file and feeds it at 44.1 kHz stereo. */
        fun addFile(path: String) {
            val ex = MediaExtractor()
            ex.setDataSource(path)
            var track = -1
            for (i in 0 until ex.trackCount) {
                if (ex.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) { track = i; break }
            }
            if (track < 0) { ex.release(); return }
            ex.selectTrack(track)
            val inFormat = ex.getTrackFormat(track)
            var rate = inFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = inFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val dec = MediaCodec.createDecoderByType(inFormat.getString(MediaFormat.KEY_MIME)!!)
            dec.configure(inFormat, null, null, 0)
            dec.start()
            val pcm = java.io.ByteArrayOutputStream()
            val di = MediaCodec.BufferInfo()
            var inDone = false
            var outDone = false
            while (!outDone) {
                if (!inDone) {
                    val i = dec.dequeueInputBuffer(TIMEOUT)
                    if (i >= 0) {
                        val b = dec.getInputBuffer(i)!!
                        val n = ex.readSampleData(b, 0)
                        if (n < 0) {
                            dec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inDone = true
                        } else {
                            dec.queueInputBuffer(i, 0, n, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val o = dec.dequeueOutputBuffer(di, TIMEOUT)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    rate = dec.outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = dec.outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                } else if (o >= 0) {
                    if (di.size > 0) {
                        val b = dec.getOutputBuffer(o)!!
                        val bytes = ByteArray(di.size)
                        b.position(di.offset)
                        b.get(bytes)
                        pcm.write(bytes)
                    }
                    dec.releaseOutputBuffer(o, false)
                    if (di.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outDone = true
                }
            }
            dec.stop(); dec.release(); ex.release()
            val shorts = ByteBuffer.wrap(pcm.toByteArray()).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
            val src = ShortArray(shorts.remaining()).also { shorts.get(it) }
            val stereo = toStereo44k(src, rate, channels)
            val bytes = ByteBuffer.allocate(stereo.size * 2).order(ByteOrder.LITTLE_ENDIAN)
            bytes.asShortBuffer().put(stereo)
            val all = bytes.array()
            var at = 0
            while (at < all.size) {
                val n = minOf(8192, all.size - at)
                feed(all.copyOfRange(at, at + n), n)
                at += n
            }
        }

        private fun toStereo44k(src: ShortArray, rate: Int, channels: Int): ShortArray {
            val ch = channels.coerceAtLeast(1)
            val inFrames = src.size / ch
            if (rate == RATE && ch == 2) return src
            val outFrames = (inFrames.toLong() * RATE / rate).toInt()
            val out = ShortArray(outFrames * 2)
            for (i in 0 until outFrames) {
                val pos = i.toDouble() * rate / RATE
                val a = pos.toInt().coerceAtMost(inFrames - 1)
                val b = (a + 1).coerceAtMost(inFrames - 1)
                val k = pos - a
                for (c in 0..1) {
                    val sc = if (ch == 1) 0 else c
                    val v = src[a * ch + sc] * (1 - k) + src[b * ch + sc] * k
                    out[i * 2 + c] = v.toInt().toShort()
                }
            }
            return out
        }

        private fun feed(data: ByteArray, size: Int) {
            var at = 0
            while (at < size) {
                val i = encoder.dequeueInputBuffer(TIMEOUT)
                if (i >= 0) {
                    val b = encoder.getInputBuffer(i)!!
                    b.clear()
                    val n = minOf(b.remaining(), size - at)
                    b.put(data, at, n)
                    val pts = framesWritten * 1_000_000L / RATE
                    encoder.queueInputBuffer(i, 0, n, pts, 0)
                    framesWritten += n / (CHANNELS * 2)
                    at += n
                }
                drain(false)
            }
        }

        fun finish() {
            var i: Int
            do {
                i = encoder.dequeueInputBuffer(TIMEOUT)
                if (i < 0) drain(false)
            } while (i < 0)
            encoder.queueInputBuffer(i, 0, 0, framesWritten * 1_000_000L / RATE, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            drain(true)
            encoder.stop()
            encoder.release()
        }

        private fun drain(end: Boolean) {
            while (true) {
                val o = encoder.dequeueOutputBuffer(info, if (end) TIMEOUT else 0)
                when {
                    o == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!end) return
                    o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> format = encoder.outputFormat
                    o >= 0 -> {
                        val b = encoder.getOutputBuffer(o)!!
                        if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                            val bytes = ByteArray(info.size)
                            b.position(info.offset)
                            b.get(bytes)
                            samples.add(Sample(bytes, info.presentationTimeUs, info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME))
                        }
                        encoder.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }
    }
}

/** Hands the finished videos (cache/videos) to WhatsApp, Instagram, Facebook… */
class VideoProvider : ContentProvider() {
    private fun file(uri: Uri): File {
        val dir = File(context!!.cacheDir, "videos")
        val f = File(dir, uri.lastPathSegment ?: "")
        if (f.parentFile?.canonicalPath != dir.canonicalPath) throw SecurityException("outside videos")
        return f
    }

    override fun onCreate() = true
    override fun getType(uri: Uri) = "video/mp4"
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor =
        ParcelFileDescriptor.open(file(uri), ParcelFileDescriptor.MODE_READ_ONLY)

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, args: Array<out String>?, sort: String?): Cursor {
        val f = file(uri)
        val cols = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val c = MatrixCursor(cols)
        val row = arrayOfNulls<Any>(cols.size)
        cols.forEachIndexed { i, col ->
            row[i] = when (col) {
                OpenableColumns.SIZE -> f.length()
                OpenableColumns.DISPLAY_NAME -> f.name
                else -> null
            }
        }
        c.addRow(row)
        return c
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, args: Array<out String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, args: Array<out String>?) = 0
}
