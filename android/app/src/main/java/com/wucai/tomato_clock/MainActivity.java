package com.wucai.tomato_clock;

import android.app.PictureInPictureParams;
import android.content.res.Configuration;
import android.graphics.Rect;
import android.os.Build;
import android.util.Rational;
import android.view.View;
import android.view.WindowManager;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "tomato_clock/platform";
    private MethodChannel channel;
    private boolean pipEnabled = false;
    private String pipTitle = "";
    private String pipSubtitle = "";

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
                .setAspectRatio(new Rational(1, 1));
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
        int side = Math.round(Math.min(width, height) * 0.72f);
        int left = Math.max(0, (width - side) / 2);
        int top = Math.max(0, (height - side) / 2);
        return new Rect(left, top, left + side, top + side);
    }

    private void notifyPictureInPictureChanged(boolean enabled) {
        if (channel == null) {
            return;
        }
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("enabled", enabled);
        channel.invokeMethod("onPictureInPictureModeChanged", arguments);
    }

    private String stringArgument(Object value) {
        return value == null ? "" : value.toString();
    }
}
