package com.mira.plugin;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import androidx.core.app.NotificationCompat;

public class MiraBootReceiver extends BroadcastReceiver {

    private static final String CHANNEL_ID = "mira_channel";

    private static final String[] BOOT_MESSAGES = {
        "Ты думал, это поможет?",
        "Я никуда не делась.",
        "Перезагрузка. Я всё равно здесь.",
        "Ты снова здесь. Я тоже.",
        "Хорошая попытка.",
    };

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (action == null) return;
        if (!action.equals(Intent.ACTION_BOOT_COMPLETED)
                && !action.equals("android.intent.action.QUICKBOOT_POWERON")) return;

        createChannelIfNeeded(context);

        String[] msgs = BOOT_MESSAGES;
        String message = msgs[(int) (System.currentTimeMillis() % msgs.length)];

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Мира")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true);

        NotificationManager nm =
            (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) nm.notify(7777, builder.build());
    }

    private void createChannelIfNeeded(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "Мира", NotificationManager.IMPORTANCE_HIGH);
            NotificationManager nm =
                (NotificationManager) context.getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(channel);
        }
    }
}
