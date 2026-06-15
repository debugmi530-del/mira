package com.mira.plugin;

import android.app.admin.DeviceAdminReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class MiraDeviceAdminReceiver extends DeviceAdminReceiver {

    private static final String TAG = "MiraDeviceAdmin";

    @Override
    public void onEnabled(Context context, Intent intent) {
        super.onEnabled(context, intent);
        Log.d(TAG, "Device Admin enabled");
    }

    @Override
    public void onDisabled(Context context, Intent intent) {
        super.onDisabled(context, intent);
        Log.d(TAG, "Device Admin disabled");
    }
}
