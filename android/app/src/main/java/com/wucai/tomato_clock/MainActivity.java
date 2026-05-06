package com.wucai.tomato_clock;

import android.app.PendingIntent;
import android.app.PictureInPictureParams;
import android.app.RemoteAction;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.Configuration;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Bundle;
import android.util.Rational;
import android.view.WindowManager;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "tomato_clock/platform";
    private static final String ACTION_TOGGLE_KEEP_SCREEN_ON =
            "com.wucai.tomato_clock.TOGGLE_KEEP_SCREEN_ON";
    private MethodChannel channel;
    private boolean pipEnabled = false;
    private boolean keepScreenOn = false;
    private String pipTitle = "";
    private String pipSubtitle = "";
    private boolean receiverRegistered = false;

    private final BroadcastReceiver pipActionReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (ACTION_TOGGLE_KEEP_SCREEN_ON.equals(intent.getAction())) {
                toggleKeepScreenOnFromPip();
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        registerPipActionReceiver();
    }

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
                case "enterPictureInPicture":
                    result.success(enterPictureInPictureIfPossible());
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    @Override
    protected void onDestroy() {
        if (receiverRegistered) {
            unregisterReceiver(pipActionReceiver);
            receiverRegistered = false;
        }
        super.onDestroy();
    }

    @Override
    public void onUserLeaveHint() {
        if (pipEnabled) {
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
        keepScreenOn = enabled;
        if (enabled) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        } else {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
        updatePictureInPictureParams();
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

    private PictureInPictureParams buildPictureInPictureParams() {
        PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder()
                .setAspectRatio(new Rational(21, 9));
        builder.setActions(Collections.singletonList(buildKeepScreenOnAction()));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder
                    .setTitle(pipTitle)
                    .setSubtitle(pipSubtitle)
                    .setAutoEnterEnabled(pipEnabled);
        }
        return builder.build();
    }

    private RemoteAction buildKeepScreenOnAction() {
        Intent intent = new Intent(ACTION_TOGGLE_KEEP_SCREEN_ON);
        intent.setPackage(getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        PendingIntent pendingIntent = PendingIntent.getBroadcast(this, 7, intent, flags);
        String title = keepScreenOn ? "关闭常亮" : "开启常亮";
        RemoteAction action = new RemoteAction(
                Icon.createWithResource(this, R.drawable.ic_pip_keep_awake),
                title,
                title,
                pendingIntent
        );
        action.setEnabled(true);
        return action;
    }

    private void toggleKeepScreenOnFromPip() {
        setKeepScreenOn(!keepScreenOn);
        notifyKeepScreenOnChanged(keepScreenOn);
    }

    private void notifyPictureInPictureChanged(boolean enabled) {
        if (channel == null) {
            return;
        }
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("enabled", enabled);
        channel.invokeMethod("onPictureInPictureModeChanged", arguments);
    }

    private void notifyKeepScreenOnChanged(boolean enabled) {
        if (channel == null) {
            return;
        }
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("enabled", enabled);
        channel.invokeMethod("onKeepScreenOnChanged", arguments);
    }

    private void registerPipActionReceiver() {
        IntentFilter filter = new IntentFilter(ACTION_TOGGLE_KEEP_SCREEN_ON);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(pipActionReceiver, filter);
        }
        receiverRegistered = true;
    }

    private String stringArgument(Object value) {
        return value == null ? "" : value.toString();
    }
}
