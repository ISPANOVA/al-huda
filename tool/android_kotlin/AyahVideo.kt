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
    }

    // ------------------------------------------------------------ render ---

    /** Writes the MP4 to [out]; returns its length in milliseconds. */
    fun render(segments: List<Segment>, width: Int, height: Int, fps: Int, out: String): Long {
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
        val mixed = ByteArray(width * height * 3 / 2)
        fun yuv(path: String): ByteArray = cache.getOrPut(path) {
            if (cache.size > 3) cache.remove(cache.keys.first())
            toI420(path, width, height)
        }
        var span = 0
        for (f in 0 until frames) {
            val pts = f * frameUs
            while (span < spans.size - 1 && pts >= spans[span].endUs) span++
            val cur = yuv(spans[span].image)
            val into = pts - spans[span].startUs
            val frame = if (span > 0 && into < fade && spans[span - 1].image != spans[span].image) {
                val prev = yuv(spans[span - 1].image)
                val k = (into * 256 / fade).toInt().coerceIn(0, 256)
                for (i in mixed.indices) mixed[i] = (((prev[i].toInt() and 255) * (256 - k) + (cur[i].toInt() and 255) * k) shr 8).toByte()
                mixed
            } else cur
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
