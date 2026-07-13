package com.follow.clash.service

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import com.follow.clash.core.Core
import com.follow.clash.service.modules.ServiceModules

class CommonService : Service(), IBaseService {
    private val modules = ServiceModules(this)

    override fun onCreate() {
        super.onCreate()
        handleCreate()
    }

    override fun onDestroy() {
        modules.stop()
        handleDestroy()
        super.onDestroy()
    }

    override fun onLowMemory() {
        Core.forceGC()
        super.onLowMemory()
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): CommonService = this@CommonService
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    override fun start() {
        try {
            modules.start()
        } catch (_: Exception) {
            stop()
        }
    }

    override fun stop() {
        modules.stop()
        stopSelf()
    }
}
