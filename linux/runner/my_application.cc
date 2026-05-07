#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <cstring>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* platform_channel;
  GDBusProxy* notifications_proxy;
  guint32 timer_notification_id;
  guint keep_screen_on_cookie;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static constexpr char kPlatformChannelName[] = "tomato_clock/platform";
static constexpr char kAppDisplayName[] = "苷";
static constexpr char kNotificationIcon[] = "appointment-soon";

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static gboolean respond_success(FlMethodCall* method_call, FlValue* result) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, result, &error)) {
    g_warning("Failed to respond to platform method: %s", error->message);
    return FALSE;
  }
  return TRUE;
}

static gboolean respond_error(FlMethodCall* method_call,
                              const gchar* code,
                              const gchar* message) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_error(method_call, code, message, nullptr,
                                    &error)) {
    g_warning("Failed to respond to platform method error: %s",
              error->message);
    return FALSE;
  }
  return TRUE;
}

static FlValue* lookup_arg(FlMethodCall* method_call, const gchar* key) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(args, key);
}

static gboolean bool_argument(FlMethodCall* method_call,
                              const gchar* key,
                              gboolean fallback) {
  FlValue* value = lookup_arg(method_call, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return fallback;
  }
  return fl_value_get_bool(value);
}

static gint int_argument(FlMethodCall* method_call,
                         const gchar* key,
                         gint fallback) {
  FlValue* value = lookup_arg(method_call, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
    return fallback;
  }
  return static_cast<gint>(fl_value_get_int(value));
}

static const gchar* string_argument(FlMethodCall* method_call,
                                    const gchar* key) {
  FlValue* value = lookup_arg(method_call, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return "";
  }
  return fl_value_get_string(value);
}

static GDBusProxy* get_notifications_proxy(MyApplication* self) {
  if (self->notifications_proxy != nullptr) {
    return self->notifications_proxy;
  }

  g_autoptr(GError) error = nullptr;
  self->notifications_proxy = g_dbus_proxy_new_for_bus_sync(
      G_BUS_TYPE_SESSION,
      static_cast<GDBusProxyFlags>(G_DBUS_PROXY_FLAGS_DO_NOT_LOAD_PROPERTIES |
                                   G_DBUS_PROXY_FLAGS_DO_NOT_CONNECT_SIGNALS),
      nullptr, "org.freedesktop.Notifications",
      "/org/freedesktop/Notifications", "org.freedesktop.Notifications",
      nullptr, &error);
  if (self->notifications_proxy == nullptr) {
    g_warning("Failed to connect to desktop notifications: %s",
              error->message);
  }
  return self->notifications_proxy;
}

static gint clamp_int(gint value, gint min_value, gint max_value) {
  if (value < min_value) {
    return min_value;
  }
  if (value > max_value) {
    return max_value;
  }
  return value;
}

static void close_timer_notification(MyApplication* self) {
  if (self->timer_notification_id == 0) {
    return;
  }

  GDBusProxy* proxy = get_notifications_proxy(self);
  if (proxy != nullptr) {
    g_autoptr(GError) error = nullptr;
    g_dbus_proxy_call_sync(
        proxy, "CloseNotification",
        g_variant_new("(u)", self->timer_notification_id),
        G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
    if (error != nullptr) {
      g_debug("Failed to close desktop notification: %s", error->message);
    }
  }
  self->timer_notification_id = 0;
}

static void set_timer_notification(MyApplication* self,
                                   gboolean enabled,
                                   const gchar* title,
                                   const gchar* subtitle,
                                   gint total_seconds,
                                   gint remaining_seconds) {
  if (!enabled) {
    close_timer_notification(self);
    return;
  }

  GDBusProxy* proxy = get_notifications_proxy(self);
  if (proxy == nullptr) {
    return;
  }

  gint safe_total = total_seconds > 0 ? total_seconds : 1;
  gint safe_remaining = clamp_int(remaining_seconds, 0, safe_total);
  gint elapsed = safe_total - safe_remaining;
  gint progress = clamp_int((elapsed * 100) / safe_total, 0, 100);
  g_autofree gchar* summary =
      g_strdup_printf("%s · %s", subtitle, title);
  g_autofree gchar* body = g_strdup_printf("剩余 %s", title);

  GVariantBuilder actions;
  g_variant_builder_init(&actions, G_VARIANT_TYPE("as"));

  GVariantBuilder hints;
  g_variant_builder_init(&hints, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&hints, "{sv}", "desktop-entry",
                        g_variant_new_string(APPLICATION_ID));
  g_variant_builder_add(&hints, "{sv}", "category",
                        g_variant_new_string("x-kde.timer"));
  g_variant_builder_add(&hints, "{sv}", "x-kde-origin-name",
                        g_variant_new_string(kAppDisplayName));
  g_variant_builder_add(&hints, "{sv}", "resident",
                        g_variant_new_boolean(TRUE));
  g_variant_builder_add(&hints, "{sv}", "suppress-sound",
                        g_variant_new_boolean(TRUE));
  g_variant_builder_add(&hints, "{sv}", "urgency", g_variant_new_byte(0));
  g_variant_builder_add(&hints, "{sv}", "value",
                        g_variant_new_int32(progress));

  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) response = g_dbus_proxy_call_sync(
      proxy, "Notify",
      g_variant_new("(susss@as@a{sv}i)", kAppDisplayName,
                    self->timer_notification_id, kNotificationIcon, summary,
                    body, g_variant_builder_end(&actions),
                    g_variant_builder_end(&hints), 0),
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (response == nullptr) {
    g_warning("Failed to send desktop notification: %s", error->message);
    return;
  }
  g_variant_get(response, "(u)", &self->timer_notification_id);
}

static void set_keep_screen_on(MyApplication* self, gboolean enabled) {
  if (enabled && self->keep_screen_on_cookie == 0) {
    self->keep_screen_on_cookie = gtk_application_inhibit(
        GTK_APPLICATION(self), self->window, GTK_APPLICATION_INHIBIT_IDLE,
        "番茄钟计时进行中");
    return;
  }
  if (!enabled && self->keep_screen_on_cookie != 0) {
    gtk_application_uninhibit(GTK_APPLICATION(self),
                              self->keep_screen_on_cookie);
    self->keep_screen_on_cookie = 0;
  }
}

static GFile* file_for_path_or_uri(const gchar* value) {
  if (g_str_has_prefix(value, "file://")) {
    return g_file_new_for_uri(value);
  }
  return g_file_new_for_path(value);
}

static gboolean display_name_is_safe(const gchar* value) {
  return value != nullptr && value[0] != '\0' && std::strchr(value, '/') == nullptr;
}

static gchar* run_file_chooser(MyApplication* self,
                               const gchar* title,
                               GtkFileChooserAction action) {
  GtkFileChooserNative* dialog = gtk_file_chooser_native_new(
      title, self->window, action, "选择", "取消");
  gtk_file_chooser_set_local_only(GTK_FILE_CHOOSER(dialog), TRUE);
  if (action == GTK_FILE_CHOOSER_ACTION_OPEN) {
    GtkFileFilter* filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "JSON 同步文件");
    gtk_file_filter_add_mime_type(filter, "application/json");
    gtk_file_filter_add_pattern(filter, "*.json");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);
    g_object_unref(filter);
  }

  gint response = gtk_native_dialog_run(GTK_NATIVE_DIALOG(dialog));
  gchar* filename = nullptr;
  if (response == GTK_RESPONSE_ACCEPT) {
    filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
  }
  g_object_unref(dialog);
  return filename;
}

static void handle_pick_directory(MyApplication* self,
                                  FlMethodCall* method_call) {
  g_autofree gchar* filename = run_file_chooser(
      self, "选择同步目录", GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER);
  if (filename == nullptr) {
    respond_success(method_call, nullptr);
    return;
  }
  g_autoptr(FlValue) result = fl_value_new_string(filename);
  respond_success(method_call, result);
}

static void handle_pick_backup_file(MyApplication* self,
                                    FlMethodCall* method_call) {
  g_autofree gchar* filename = run_file_chooser(
      self, "选择同步文件", GTK_FILE_CHOOSER_ACTION_OPEN);
  if (filename == nullptr) {
    respond_success(method_call, nullptr);
    return;
  }
  g_autoptr(FlValue) result = fl_value_new_string(filename);
  respond_success(method_call, result);
}

static void handle_read_text_file(FlMethodCall* method_call) {
  const gchar* file_uri = string_argument(method_call, "fileUri");
  if (file_uri[0] == '\0') {
    respond_error(method_call, "invalid_file_uri", "File path is empty.");
    return;
  }

  g_autoptr(GFile) file = file_for_path_or_uri(file_uri);
  g_autofree gchar* contents = nullptr;
  gsize length = 0;
  g_autoptr(GError) error = nullptr;
  if (!g_file_load_contents(file, nullptr, &contents, &length, nullptr,
                            &error)) {
    respond_error(method_call, "read_text_file_failed", error->message);
    return;
  }

  g_autoptr(FlValue) result = fl_value_new_string_sized(contents, length);
  respond_success(method_call, result);
}

static void handle_write_text_file(FlMethodCall* method_call) {
  const gchar* directory_uri = string_argument(method_call, "directoryUri");
  const gchar* display_name = string_argument(method_call, "displayName");
  const gchar* contents = string_argument(method_call, "contents");
  if (directory_uri[0] == '\0') {
    respond_error(method_call, "invalid_directory", "Directory path is empty.");
    return;
  }
  if (!display_name_is_safe(display_name)) {
    respond_error(method_call, "invalid_display_name",
                  "Display name must be a plain file name.");
    return;
  }

  g_autoptr(GFile) directory = file_for_path_or_uri(directory_uri);
  g_autoptr(GFile) file = g_file_get_child(directory, display_name);
  g_autoptr(GError) error = nullptr;
  if (!g_file_make_directory_with_parents(directory, nullptr, &error) &&
      !g_error_matches(error, G_IO_ERROR, G_IO_ERROR_EXISTS)) {
    respond_error(method_call, "create_directory_failed", error->message);
    return;
  }

  g_clear_error(&error);
  gsize length = std::strlen(contents);
  if (!g_file_replace_contents(file, contents, length, nullptr, FALSE,
                               G_FILE_CREATE_REPLACE_DESTINATION, nullptr,
                               nullptr, &error)) {
    respond_error(method_call, "write_text_file_failed", error->message);
    return;
  }

  g_autofree gchar* path = g_file_get_path(file);
  if (path == nullptr) {
    path = g_file_get_uri(file);
  }
  g_autoptr(FlValue) result = fl_value_new_string(path);
  respond_success(method_call, result);
}

static void open_notification_settings() {
  const gchar* commands[] = {"kcmshell6", "kcmshell5", "systemsettings",
                             nullptr};
  for (gint i = 0; commands[i] != nullptr; ++i) {
    g_autofree gchar* command_path = g_find_program_in_path(commands[i]);
    if (command_path == nullptr) {
      continue;
    }
    const gchar* argv[] = {command_path, "kcm_notifications", nullptr};
    g_autoptr(GError) error = nullptr;
    if (g_spawn_async(nullptr, const_cast<gchar**>(argv), nullptr,
                      G_SPAWN_SEARCH_PATH, nullptr, nullptr, nullptr,
                      &error)) {
      return;
    }
    g_warning("Failed to open notification settings: %s", error->message);
  }
}

static void platform_method_call_cb(FlMethodChannel* channel,
                                    FlMethodCall* method_call,
                                    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (g_strcmp0(method, "setKeepScreenOn") == 0) {
    set_keep_screen_on(self, bool_argument(method_call, "enabled", FALSE));
    respond_success(method_call, nullptr);
  } else if (g_strcmp0(method, "setTimerNotification") == 0) {
    set_timer_notification(
        self, bool_argument(method_call, "enabled", FALSE),
        string_argument(method_call, "title"),
        string_argument(method_call, "subtitle"),
        int_argument(method_call, "totalSeconds", 1),
        int_argument(method_call, "remainingSeconds", 1));
    respond_success(method_call, nullptr);
  } else if (g_strcmp0(method, "requestNotificationPermission") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    respond_success(method_call, result);
  } else if (g_strcmp0(method, "openNotificationSettings") == 0) {
    open_notification_settings();
    respond_success(method_call, nullptr);
  } else if (g_strcmp0(method, "pickDirectory") == 0) {
    handle_pick_directory(self, method_call);
  } else if (g_strcmp0(method, "pickBackupFile") == 0) {
    handle_pick_backup_file(self, method_call);
  } else if (g_strcmp0(method, "readTextFile") == 0) {
    handle_read_text_file(method_call);
  } else if (g_strcmp0(method, "writeTextFile") == 0) {
    handle_write_text_file(method_call);
  } else if (g_strcmp0(method, "playCompletionSound") == 0) {
    gdk_display_beep(gdk_display_get_default());
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    respond_success(method_call, result);
  } else if (g_strcmp0(method, "vibrate") == 0 ||
             g_strcmp0(method, "vibratePattern") == 0 ||
             g_strcmp0(method, "setPipState") == 0 ||
             g_strcmp0(method, "enterPictureInPicture") == 0) {
    respond_success(method_call, nullptr);
  } else {
    g_autoptr(GError) error = nullptr;
    if (!fl_method_call_respond_not_implemented(method_call, &error)) {
      g_warning("Failed to respond not implemented: %s", error->message);
    }
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "苷");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "苷");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->platform_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      kPlatformChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->platform_channel, platform_method_call_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  close_timer_notification(self);
  set_keep_screen_on(self, FALSE);

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  close_timer_notification(self);
  set_keep_screen_on(self, FALSE);
  g_clear_object(&self->platform_channel);
  g_clear_object(&self->notifications_proxy);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
