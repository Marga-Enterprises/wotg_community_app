package com.wotgonline.wotg_community

import android.app.*
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import java.net.URL

class MediaPlayerService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val CHANNEL_ID = "WOTG_AUDIO_CHANNEL"

    private val ACTION_PLAY = "com.wotg.PLAY"
    private val ACTION_PAUSE = "com.wotg.PAUSE"
    private val ACTION_NEXT = "com.wotg.NEXT"
    private val ACTION_PREV = "com.wotg.PREV"

    private val trackList = mutableListOf<Track>()
    private var currentIndex = 0

    private var title: String = ""
    private var artist: String = ""
    private var cover: String = ""

    data class Track(val url: String, val title: String, val artist: String, val cover: String)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        when (intent.action) {
            ACTION_PLAY -> {
                mediaPlayer?.start()
                updateNotification()
                return START_STICKY
            }
            ACTION_PAUSE -> {
                mediaPlayer?.pause()
                updateNotification()
                return START_STICKY
            }
            ACTION_NEXT -> {
                if (currentIndex + 1 < trackList.size) {
                    currentIndex++
                    playTrack(currentIndex)
                }
                return START_STICKY
            }
            ACTION_PREV -> {
                if (currentIndex > 0) {
                    currentIndex--
                    playTrack(currentIndex)
                }
                return START_STICKY
            }
        }

        // First track (from Dart/JS)
        val url = intent.getStringExtra("url") ?: return START_NOT_STICKY
        val t = intent.getStringExtra("title") ?: "Now Playing"
        val a = intent.getStringExtra("artist") ?: ""
        val c = intent.getStringExtra("cover") ?: ""

        trackList.clear()
        trackList.add(Track(url, t, a, c))
        currentIndex = 0
        playTrack(currentIndex)

        return START_STICKY
    }

    private fun playTrack(index: Int) {
        val track = trackList[index]
        title = track.title
        artist = track.artist
        cover = track.cover

        mediaPlayer?.release()
        mediaPlayer = MediaPlayer().apply {
            setDataSource(applicationContext, Uri.parse(track.url))
            prepare()
            start()
            setOnCompletionListener {
                stopSelf() // You can change this to auto-play next
            }
        }

        createNotificationChannel()
        startForeground(1, buildNotification(isPlaying = true))
    }

    private fun updateNotification() {
        val notification = buildNotification(mediaPlayer?.isPlaying == true)
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(1, notification)
    }

    private fun buildNotification(isPlaying: Boolean): Notification {
        val playPauseAction = if (isPlaying) {
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause, "Pause", getActionIntent(ACTION_PAUSE)
            )
        } else {
            NotificationCompat.Action(
                android.R.drawable.ic_media_play, "Play", getActionIntent(ACTION_PLAY)
            )
        }

        val prevAction = NotificationCompat.Action(
            android.R.drawable.ic_media_previous, "Previous", getActionIntent(ACTION_PREV)
        )

        val nextAction = NotificationCompat.Action(
            android.R.drawable.ic_media_next, "Next", getActionIntent(ACTION_NEXT)
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(artist)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setStyle(MediaStyle().setShowActionsInCompactView(0, 1, 2))
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)

        // Album Art (optional)
        try {
            if (cover.isNotEmpty()) {
                val url = URL(cover)
                val bitmap = BitmapFactory.decodeStream(url.openStream())
                builder.setLargeIcon(bitmap)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return builder.build()
    }

    private fun getActionIntent(action: String): PendingIntent {
        val intent = Intent(this, MediaPlayerService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "WOTG Audio Playback",
                NotificationManager.IMPORTANCE_HIGH
            )
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        mediaPlayer?.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
