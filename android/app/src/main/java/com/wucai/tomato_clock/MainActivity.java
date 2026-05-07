package com.wucai.tomato_clock;

import android.app.PictureInPictureParams;
import android.media.AudioAttributes;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.ContentResolver;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Rect;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.content.pm.PackageManager;
import android.os.VibrationEffect;
import android.os.VibratorManager;
import android.util.Rational;
import android.view.View;
import android.view.WindowManager;
import android.provider.DocumentsContract;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import androidx.activity.result.ActivityResult;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "tomato_clock/platform";
    private static final String NOTIFICATION_CHANNEL_ID = "timer_progress";
    private static final int NOTIFICATION_ID = 1001;
    private final ActivityResultLauncher<String> requestNotificationPermissionLauncher =
            registerForActivityResult(
                    new ActivityResultContracts.RequestPermission(),
                    this::handleNotificationPermissionResult
            );
    private final ActivityResultLauncher<Intent> pickDirectoryLauncher =
            registerForActivityResult(
                    new ActivityResultContracts.StartActivityForResult(),
                    this::handlePickDirectoryResult
            );
    private MethodChannel channel;
    private boolean pipEnabled = false;
    private String pipTitle = "";
    private String pipSubtitle = "";
    private Result pendingPickResult;
    private Result pendingPickBackupFileResult;
    private Result pendingNotificationPermissionResult;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        channel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        );
        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "setKeepScreenOn":
                    setKeepScreenOn(Boolean.TRUE.equals(call.argument("enabled")));
                    result.success(null);
                    break;
                case "setPipState":
                    pipEnabled = Boolean.TRUE.equals(call.argument("enabled"));
                    pipTitle = stringArgument(call.argument("title"));
                    pipSubtitle = stringArgument(call.argument("subtitle"));
                    updatePictureInPictureParams();
                    result.success(null);
                    break;
                case "setTimerNotification":
                    setTimerNotification(
                            Boolean.TRUE.equals(call.argument("enabled")),
                            stringArgument(call.argument("title")),
                            stringArgument(call.argument("subtitle")),
                            intArgument(call.argument("totalSeconds"), 0),
                            intArgument(call.argument("remainingSeconds"), 0)
                    );
                    result.success(null);
                    break;
                case "requestNotificationPermission":
                    requestNotificationPermission(result);
                    break;
                case "openNotificationSettings":
                    openNotificationSettings();
                    result.success(null);
                    break;
                case "enterPictureInPicture":
                    result.success(enterPictureInPictureIfPossible());
                    break;
                case "pickDirectory":
                    pickDirectory(result);
                    break;
                case "writeTextFile":
                    writeTextFile(
                            stringArgument(call.argument("directoryUri")),
                            stringArgument(call.argument("displayName")),
                            stringArgument(call.argument("contents")),
                            result
                    );
                    break;
                case "pickBackupFile":
                    pickBackupFile(result);
                    break;
                case "readTextFile":
                    readTextFile(stringArgument(call.argument("fileUri")), result);
                    break;
                case "playCompletionSound":
                    result.success(playCompletionSound());
                    break;
                case "vibrate":
                    vibrate(intArgument(call.argument("durationMs"), 900),
                            intArgument(call.argument("amplitude"), -1));
                    result.success(null);
                    break;
                case "vibratePattern":
                    vibratePattern(call.argument("timingsMs"), call.argument("amplitudes"));
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    @Override
    public void onUserLeaveHint() {
        if (pipEnabled && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPictureInPictureIfPossible();
        }
        super.onUserLeaveHint();
    }

    @Override
    public void onPictureInPictureModeChanged(
            boolean isInPictureInPictureMode,
            Configuration newConfig
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig);
        notifyPictureInPictureChanged(isInPictureInPictureMode);
    }

    private void setKeepScreenOn(boolean enabled) {
        if (enabled) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        } else {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
        updatePictureInPictureParams();
    }

    private void requestNotificationPermission(Result result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true);
            return;
        }
        if (ActivityCompat.checkSelfPermission(
                this,
                android.Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED) {
            result.success(true);
            return;
        }
        if (pendingNotificationPermissionResult != null) {
            result.error(
                    "notification_permission_in_progress",
                    "Notification permission request is already in progress.",
                    null
            );
            return;
        }
        pendingNotificationPermissionResult = result;
        requestNotificationPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS);
    }

    private void handleNotificationPermissionResult(boolean granted) {
        if (pendingNotificationPermissionResult == null) {
            return;
        }
        pendingNotificationPermissionResult.success(granted);
        pendingNotificationPermissionResult = null;
    }

    private void openNotificationSettings() {
        Intent intent = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(intent);
        } catch (ActivityNotFoundException ignored) {
            // No fallback needed; users can still adjust settings manually.
        }
    }

    private void updatePictureInPictureParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            setPictureInPictureParams(buildPictureInPictureParams());
        }
    }

    private boolean enterPictureInPictureIfPossible() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !pipEnabled) {
            return false;
        }
        return enterPictureInPictureMode(buildPictureInPictureParams());
    }

    private void pickDirectory(Result result) {
        if (pendingPickResult != null) {
            result.error("pick_directory_in_progress", "A directory picker is already open.", null);
            return;
        }

        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);

        pendingPickResult = result;
        try {
            pickDirectoryLauncher.launch(intent);
        } catch (ActivityNotFoundException exception) {
            pendingPickResult = null;
            result.error("activity_not_found", "No directory picker is available.", null);
        }
    }

    private void pickBackupFile(Result result) {
        if (pendingPickBackupFileResult != null) {
            result.error("pick_file_in_progress", "A backup file picker is already open.", null);
            return;
        }
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("application/json");
        intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "text/json", "*/*"});
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        pendingPickBackupFileResult = result;
        try {
            pickDirectoryLauncher.launch(intent);
        } catch (ActivityNotFoundException exception) {
            pendingPickBackupFileResult = null;
            result.error("activity_not_found", "No document picker is available.", null);
        }
    }

    private void handlePickDirectoryResult(ActivityResult result) {
        if (pendingPickResult == null && pendingPickBackupFileResult == null) {
            return;
        }

        Intent data = result.getData();
        if (result.getResultCode() != Activity.RESULT_OK
                || data == null
                || data.getData() == null) {
            if (pendingPickResult != null) {
                pendingPickResult.success(null);
                pendingPickResult = null;
            }
            if (pendingPickBackupFileResult != null) {
                pendingPickBackupFileResult.success(null);
                pendingPickBackupFileResult = null;
            }
            return;
        }

        Uri uri = data.getData();
        int requested = pendingPickResult != null
                ? (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                : Intent.FLAG_GRANT_READ_URI_PERMISSION;
        int flags = data.getFlags() & requested;
        try {
            if (flags != 0) {
                getContentResolver().takePersistableUriPermission(uri, flags);
            }
        } catch (SecurityException ignored) {
            // Some document providers return a usable tree Uri without persistable grants.
        }
        if (pendingPickResult != null) {
            pendingPickResult.success(uri.toString());
            pendingPickResult = null;
        } else if (pendingPickBackupFileResult != null) {
            pendingPickBackupFileResult.success(uri.toString());
            pendingPickBackupFileResult = null;
        }
    }

    private void writeTextFile(
            String directoryUriText,
            String displayName,
            String contents,
            Result result
    ) {
        if (directoryUriText.isEmpty()) {
            result.error("invalid_directory_uri", "Directory uri is empty.", null);
            return;
        }
        if (displayName.isEmpty()) {
            result.error("invalid_file_name", "Display name is empty.", null);
            return;
        }
        try {
            Uri treeUri = Uri.parse(directoryUriText);
            String treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri);
            Uri directoryUri = DocumentsContract.buildDocumentUriUsingTree(
                    treeUri,
                    treeDocumentId
            );
            ContentResolver resolver = getContentResolver();
            Uri fileUri = DocumentsContract.createDocument(
                    resolver,
                    directoryUri,
                    "application/json",
                    displayName
            );
            if (fileUri == null) {
                result.error("create_document_failed", "Failed to create document.", null);
                return;
            }
            try (OutputStream outputStream = resolver.openOutputStream(fileUri, "w")) {
                if (outputStream == null) {
                    result.error("open_stream_failed", "Failed to open output stream.", null);
                    return;
                }
                outputStream.write(contents.getBytes(StandardCharsets.UTF_8));
                outputStream.flush();
            }
            result.success(fileUri.toString());
        } catch (Exception exception) {
            result.error("write_text_file_failed", exception.getMessage(), null);
        }
    }

    private void readTextFile(String fileUriText, Result result) {
        if (fileUriText.isEmpty()) {
            result.error("invalid_file_uri", "File uri is empty.", null);
            return;
        }
        try {
            Uri fileUri = Uri.parse(fileUriText);
            try {
                getContentResolver().takePersistableUriPermission(
                        fileUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                );
            } catch (SecurityException ignored) {
                // Some providers don't grant persistable permissions.
            }
            ContentResolver resolver = getContentResolver();
            try (InputStream inputStream = resolver.openInputStream(fileUri)) {
                if (inputStream == null) {
                    result.error("open_stream_failed", "Failed to open input stream.", null);
                    return;
                }
                ByteArrayOutputStream output = new ByteArrayOutputStream();
                byte[] buffer = new byte[8192];
                int read;
                while ((read = inputStream.read(buffer)) != -1) {
                    output.write(buffer, 0, read);
                }
                result.success(output.toString(StandardCharsets.UTF_8.name()));
            }
        } catch (Exception exception) {
            result.error("read_text_file_failed", exception.getMessage(), null);
        }
    }

    private boolean playCompletionSound() {
        try {
            Uri uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
            if (uri == null) {
                uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
            }
            if (uri == null) {
                return false;
            }
            Ringtone ringtone = RingtoneManager.getRingtone(this, uri);
            if (ringtone == null) {
                return false;
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone.setVolume(1f);
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone.setAudioAttributes(
                        new AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                );
            }
            ringtone.play();
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }

    private void vibrate(int durationMs, int amplitude) {
        VibratorManager vibratorManager = getVibratorManager();
        if (vibratorManager == null) {
            return;
        }
        android.os.Vibrator vibrator = vibratorManager.getDefaultVibrator();
        if (vibrator == null || !vibrator.hasVibrator()) {
            return;
        }

        int safeDuration = Math.max(1, durationMs);
        int safeAmplitude = amplitude >= 1 && amplitude <= 255
                ? amplitude
                : VibrationEffect.DEFAULT_AMPLITUDE;
        vibrator.vibrate(VibrationEffect.createOneShot(safeDuration, safeAmplitude));
    }

    private void vibratePattern(Object timingsValue, Object amplitudesValue) {
        VibratorManager vibratorManager = getVibratorManager();
        if (vibratorManager == null) {
            return;
        }
        android.os.Vibrator vibrator = vibratorManager.getDefaultVibrator();
        if (vibrator == null || !vibrator.hasVibrator()) {
            return;
        }

        long[] timings = longArrayArgument(timingsValue);
        if (timings.length < 2) {
            vibrate(900, 255);
            return;
        }

        int[] amplitudes = amplitudeArrayArgument(amplitudesValue, timings.length);
        vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1));
    }

    private VibratorManager getVibratorManager() {
        return getSystemService(VibratorManager.class);
    }

    private PictureInPictureParams buildPictureInPictureParams() {
        PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder()
                .setAspectRatio(new Rational(9, 16));
        Rect sourceRect = buildPictureInPictureSourceRect();
        if (sourceRect != null) {
            builder.setSourceRectHint(sourceRect);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder
                    .setTitle(pipTitle)
                    .setSubtitle(pipSubtitle)
                    .setAutoEnterEnabled(pipEnabled)
                    .setSeamlessResizeEnabled(true);
        }
        return builder.build();
    }

    private Rect buildPictureInPictureSourceRect() {
        View decorView = getWindow().getDecorView();
        int width = decorView.getWidth();
        int height = decorView.getHeight();
        if (width <= 0 || height <= 0) {
            return null;
        }
        int hintWidth = Math.round(width * 0.44f);
        int hintHeight = Math.round(height * 0.44f);
        int left = Math.max(0, (width - hintWidth) / 2);
        int top = Math.max(0, (height - hintHeight) / 2);
        return new Rect(left, top, left + hintWidth, top + hintHeight);
    }

    private void notifyPictureInPictureChanged(boolean enabled) {
        if (channel == null) {
            return;
        }
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("enabled", enabled);
        channel.invokeMethod("onPictureInPictureModeChanged", arguments);
    }

    private void setTimerNotification(
            boolean enabled,
            String title,
            String subtitle,
            int totalSeconds,
            int remainingSeconds
    ) {
        NotificationManagerCompat manager = NotificationManagerCompat.from(this);
        if (!enabled) {
            manager.cancel(NOTIFICATION_ID);
            return;
        }
        if (!manager.areNotificationsEnabled()) {
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ActivityCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED) {
            return;
        }

        ensureNotificationChannel();
        int safeTotal = Math.max(1, totalSeconds);
        int safeRemaining = Math.max(0, Math.min(remainingSeconds, safeTotal));
        int elapsed = safeTotal - safeRemaining;
        String progressText = formatClock(safeRemaining);
        Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        PendingIntent pendingIntent = null;
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags |= PendingIntent.FLAG_IMMUTABLE;
            }
            pendingIntent = PendingIntent.getActivity(this, 0, intent, flags);
        }

        NotificationCompat.Builder builder = new NotificationCompat.Builder(
                this,
                NOTIFICATION_CHANNEL_ID
        )
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(subtitle + " · " + progressText)
                .setContentText(title)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setProgress(safeTotal, elapsed, false)
                .setShowWhen(false);
        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent);
        }
        manager.notify(NOTIFICATION_ID, builder.build());
    }

    private void ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager == null) {
            return;
        }
        NotificationChannel channel = manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID);
        if (channel != null) {
            return;
        }
        NotificationChannel created = new NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "番茄钟进度",
                NotificationManager.IMPORTANCE_LOW
        );
        created.setDescription("计时进行中时显示进度");
        created.setShowBadge(false);
        manager.createNotificationChannel(created);
    }

    private String formatClock(int seconds) {
        int safe = Math.max(0, seconds);
        int hours = safe / 3600;
        int minutes = (safe % 3600) / 60;
        int rest = safe % 60;
        if (hours > 0) {
            return String.format("%d:%02d:%02d", hours, minutes, rest);
        }
        return String.format("%02d:%02d", minutes, rest);
    }

    private String stringArgument(Object value) {
        return value == null ? "" : value.toString();
    }

    private int intArgument(Object value, int fallback) {
        return value instanceof Number ? ((Number) value).intValue() : fallback;
    }

    private long[] longArrayArgument(Object value) {
        if (!(value instanceof List<?>)) {
            return new long[0];
        }

        List<?> values = (List<?>) value;
        ArrayList<Long> timings = new ArrayList<>();
        for (Object item : values) {
            if (item instanceof Number) {
                timings.add(Math.max(0L, ((Number) item).longValue()));
            }
        }

        long[] result = new long[timings.size()];
        for (int i = 0; i < timings.size(); i++) {
            result[i] = timings.get(i);
        }
        return result;
    }

    private int[] amplitudeArrayArgument(Object value, int length) {
        int[] result = new int[length];
        for (int i = 0; i < length; i++) {
            result[i] = VibrationEffect.DEFAULT_AMPLITUDE;
        }

        if (!(value instanceof List<?>)) {
            return result;
        }

        List<?> values = (List<?>) value;
        int count = Math.min(length, values.size());
        for (int i = 0; i < count; i++) {
            Object item = values.get(i);
            if (item instanceof Number) {
                int amplitude = ((Number) item).intValue();
                result[i] = amplitude == 0
                        ? 0
                        : Math.max(1, Math.min(255, amplitude));
            }
        }
        return result;
    }
}
