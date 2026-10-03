package com.alhuda.islamic.app

import android.app.Activity
import android.content.ComponentName
import android.media.MediaMetadata
import android.media.browse.MediaBrowser
import android.media.session.MediaController
import android.media.session.PlaybackState
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * CI only: behaves like Android Auto. Connects to the app's media browser
 * service, lists the library, plays items by media id and logs every
 * playback state / metadata change («AUTOPROBE» in logcat).
 */
class AutoProbeActivity : Activity() {
    private val tag = "AUTOPROBE"
    private lateinit var browser: MediaBrowser
    private var controller: MediaController? = null
    private val main = Handler(Looper.getMainLooper())

    private fun stateName(s: Int) = when (s) {
        PlaybackState.STATE_NONE -> "NONE"
        PlaybackState.STATE_STOPPED -> "STOPPED"
        PlaybackState.STATE_PAUSED -> "PAUSED"
        PlaybackState.STATE_PLAYING -> "PLAYING"
        PlaybackState.STATE_BUFFERING -> "BUFFERING"
        PlaybackState.STATE_CONNECTING -> "CONNECTING"
        PlaybackState.STATE_ERROR -> "ERROR"
        PlaybackState.STATE_SKIPPING_TO_NEXT -> "SKIP_NEXT"
        else -> "S$s"
    }

    private val callback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            Log.i(tag, "STATE ${state?.let { stateName(it.state) }} pos=${state?.position} err=${state?.errorMessage} actions=${state?.actions}")
        }

        override fun onMetadataChanged(metadata: MediaMetadata?) {
            Log.i(tag, "META id=${metadata?.getString(MediaMetadata.METADATA_KEY_MEDIA_ID)} title=${metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)}")
        }

        override fun onSessionDestroyed() {
            Log.i(tag, "SESSION DESTROYED")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val service = ComponentName(this, "com.ryanheise.audioservice.AudioService")
        browser = MediaBrowser(this, service, object : MediaBrowser.ConnectionCallback() {
            override fun onConnected() {
                Log.i(tag, "CONNECTED root=${browser.root}")
                val c = MediaController(this@AutoProbeActivity, browser.sessionToken)
                controller = c
                c.registerCallback(callback, main)
                Log.i(tag, "INITIAL state=${c.playbackState?.let { stateName(it.state) }} actions=${c.playbackState?.actions}")
                browse(browser.root)
                runScript(c)
            }

            override fun onConnectionFailed() = Log.i(tag, "CONNECTION FAILED").let { }
            override fun onConnectionSuspended() = Log.i(tag, "CONNECTION SUSPENDED").let { }
        }, null)
        browser.connect()
    }

    private fun browse(id: String) {
        browser.subscribe(id, object : MediaBrowser.SubscriptionCallback() {
            override fun onChildrenLoaded(parentId: String, children: MutableList<MediaBrowser.MediaItem>) {
                Log.i(tag, "CHILDREN $parentId n=${children.size} first=${children.take(3).map { "${it.mediaId}|${it.description.title}|${it.description.iconUri}|playable=${it.isPlayable}" }}")
            }

            override fun onError(parentId: String) {
                Log.i(tag, "CHILDREN ERROR $parentId")
            }
        })
    }

    private fun runScript(c: MediaController) {
        val steps = listOf(
            3_000L to { browse("radios") },
            5_000L to { Log.i(tag, "STEP play radio:0"); c.transportControls.playFromMediaId("radio:0", null) },
            25_000L to { Log.i(tag, "STEP pause"); c.transportControls.pause() },
            30_000L to { Log.i(tag, "STEP play"); c.transportControls.play() },
            40_000L to { Log.i(tag, "STEP play msurah:basit:1"); c.transportControls.playFromMediaId("msurah:basit:1", null) },
            60_000L to { Log.i(tag, "STEP next"); c.transportControls.skipToNext() },
            75_000L to { Log.i(tag, "STEP play surah:112"); c.transportControls.playFromMediaId("surah:112", null) },
            95_000L to { Log.i(tag, "STEP search"); c.transportControls.playFromSearch("سورة الكهف للمنشاوي", null) },
            110_000L to { Log.i(tag, "STEP stop"); c.transportControls.stop() },
            115_000L to { Log.i(tag, "DONE") },
        )
        for ((at, action) in steps) main.postDelayed({ action() }, at)
        // Periodic snapshot.
        for (k in 1..23) main.postDelayed({
            val s = c.playbackState
            Log.i(tag, "TICK ${k * 5}s state=${s?.let { stateName(it.state) }} pos=${s?.position} err=${s?.errorMessage} title=${c.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)}")
        }, k * 5_000L)
    }
}
