package com.mira.plugin;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import androidx.core.app.NotificationCompat;

public class MiraAlarmReceiver extends BroadcastReceiver {

    private static final String CHANNEL_ID = "mira_channel";

    @Override
    public void onReceive(Context context, Intent intent) {
        String title = intent.getStringExtra("title");
        String body  = intent.getStringExtra("body");
        if (title == null) title = "Мира";
        if (body  == null) body  = "Я слежу.";

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "Мира", NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Уведомления от Миры");
            NotificationManager nm = context.getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(channel);
        }

        Intent openIntent = context.getPackageManager()
            .getLaunchIntentForPackage(context.getPackageName());
        if (openIntent != null) openIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent tapIntent = PendingIntent.getActivity(context, 0,
            openIntent != null ? openIntent : new Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder =
            new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(tapIntent)
                .setAutoCancel(true);

        NotificationManager nm =
            (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) nm.notify((int)(System.currentTimeMillis() / 1000), builder.build());
    }
}
