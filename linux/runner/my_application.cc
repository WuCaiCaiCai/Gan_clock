#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <libappindicator/app-indicator.h>
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
  GDBusProxy* screensaver_proxy;
  GDBusProxy* power_inhibit_proxy;
  AppIndicator* indicator;
  guint32 timer_notification_id;
  guint32 screensaver_cookie;
  guint32 power_inhibit_cookie;
  guint keep_screen_on_cookie;
  gboolean persistent_timer_notification_enabled;
  gboolean window_close_hides;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static constexpr char kPlatformChannelName[] = "tomato_clock/platform";
static constexpr char kAppDisplayName[] = "苷";
static constexpr char kNotificationIcon[] = APPLICATION_ID;

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

static GDBusProxy* get_session_proxy(GDBusProxy** proxy,
                                     const gchar* bus_name,
                                     const gchar* object_path,
                                     const gchar* interface_name) {
  if (*proxy != nullptr) {
    return *proxy;
  }

  g_autoptr(GError) error = nullptr;
  *proxy = g_dbus_proxy_new_for_bus_sync(
      G_BUS_TYPE_SESSION,
      static_cast<GDBusProxyFlags>(G_DBUS_PROXY_FLAGS_DO_NOT_LOAD_PROPERTIES |
                                   G_DBUS_PROXY_FLAGS_DO_NOT_CONNECT_SIGNALS),
      nullptr, bus_name, object_path, interface_name, nullptr, &error);
  if (*proxy == nullptr) {
    g_debug("Failed to connect to %s: %s", bus_name, error->message);
  }
  return *proxy;
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

static gchar* build_existing_path(const gchar* first_element,
                                  const gchar* second_element,
                                  const gchar* third_element = nullptr,
                                  const gchar* fourth_element = nullptr) {
  gchar* path = fourth_element != nullptr
      ? g_build_filename(first_element, second_element, third_element,
                         fourth_element, nullptr)
      : third_element != nullptr
          ? g_build_filename(first_element, second_element, third_element,
                             nullptr)
          : g_build_filename(first_element, second_element, nullptr);
  if (g_file_test(path, G_FILE_TEST_EXISTS)) {
    return path;
  }
  g_free(path);
  return nullptr;
}

static gchar* find_app_icon_path() {
  g_autofree gchar* icon_filename =
      g_strdup_printf("%s.svg", APPLICATION_ID);
  g_autofree gchar* cwd = g_get_current_dir();
  if (gchar* path = build_existing_path(cwd, "icon.svg")) {
    return path;
  }

  g_autofree gchar* executable_path = g_file_read_link("/proc/self/exe",
                                                       nullptr);
  if (executable_path != nullptr) {
    g_autofree gchar* executable_dir = g_path_get_dirname(executable_path);
    if (gchar* path =
            build_existing_path(executable_dir, "data", "icons",
                                icon_filename)) {
      return path;
    }
  }

  const gchar* home = g_get_home_dir();
  if (home != nullptr) {
    if (gchar* path = build_existing_path(
            home, ".local/share/icons/hicolor/scalable/apps",
            icon_filename)) {
      return path;
    }
  }

  return build_existing_path("/usr/share/icons/hicolor/scalable/apps",
                             icon_filename);
}

static gchar* icon_name_from_path(const gchar* icon_path) {
  if (icon_path == nullptr) {
    return g_strdup(APPLICATION_ID);
  }
  gchar* basename = g_path_get_basename(icon_path);
  gchar* extension = g_strrstr(basename, ".svg");
  if (extension != nullptr && extension[4] == '\0') {
    extension[0] = '\0';
  }
  return basename;
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
  self->persistent_timer_notification_enabled = FALSE;
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
  g_autofree gchar* icon_path = find_app_icon_path();

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
  if (icon_path != nullptr) {
    g_variant_builder_add(&hints, "{sv}", "image-path",
                          g_variant_new_string(icon_path));
  }

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
  self->persistent_timer_notification_enabled = enabled;
}

static void set_persistent_timer_notification(MyApplication* self,
                                              gboolean enabled) {
  if (!enabled) {
    close_timer_notification(self);
    return;
  }
  if (self->persistent_timer_notification_enabled &&
      self->timer_notification_id != 0) {
    return;
  }

  GDBusProxy* proxy = get_notifications_proxy(self);
  if (proxy == nullptr) {
    return;
  }

  g_autofree gchar* icon_path = find_app_icon_path();
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
  if (icon_path != nullptr) {
    g_variant_builder_add(&hints, "{sv}", "image-path",
                          g_variant_new_string(icon_path));
  }

  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) response = g_dbus_proxy_call_sync(
      proxy, "Notify",
      g_variant_new("(susss@as@a{sv}i)", kAppDisplayName,
                    self->timer_notification_id, kNotificationIcon,
                    "番茄钟运行中", "可从系统托盘打开或退出。",
                    g_variant_builder_end(&actions),
                    g_variant_builder_end(&hints), 0),
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (response == nullptr) {
    g_warning("Failed to send persistent notification: %s", error->message);
    return;
  }
  g_variant_get(response, "(u)", &self->timer_notification_id);
  self->persistent_timer_notification_enabled = TRUE;
}

static void show_main_window(MyApplication* self) {
  if (self->window == nullptr) {
    return;
  }
  gtk_widget_show(GTK_WIDGET(self->window));
  gtk_window_present(self->window);
}

static void show_menu_item_activate_cb(GtkMenuItem* item, gpointer user_data) {
  show_main_window(MY_APPLICATION(user_data));
}

static void quit_menu_item_activate_cb(GtkMenuItem* item, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->window_close_hides = FALSE;
  close_timer_notification(self);
  g_application_quit(G_APPLICATION(self));
}

static void ensure_tray_indicator(MyApplication* self) {
  if (self->indicator != nullptr) {
    return;
  }

  g_autofree gchar* icon_path = find_app_icon_path();
  g_autofree gchar* icon_name = icon_name_from_path(icon_path);
  g_autofree gchar* icon_dir =
      icon_path == nullptr ? nullptr : g_path_get_dirname(icon_path);
  self->indicator = icon_dir == nullptr
      ? app_indicator_new(APPLICATION_ID, icon_name,
                          APP_INDICATOR_CATEGORY_APPLICATION_STATUS)
      : app_indicator_new_with_path(APPLICATION_ID, icon_name,
                                    APP_INDICATOR_CATEGORY_APPLICATION_STATUS,
                                    icon_dir);
  app_indicator_set_title(self->indicator, kAppDisplayName);
  app_indicator_set_status(self->indicator, APP_INDICATOR_STATUS_ACTIVE);

  GtkWidget* menu = gtk_menu_new();
  GtkWidget* show_item = gtk_menu_item_new_with_label("显示窗口");
  GtkWidget* separator = gtk_separator_menu_item_new();
  GtkWidget* quit_item = gtk_menu_item_new_with_label("退出");
  g_signal_connect(show_item, "activate",
                   G_CALLBACK(show_menu_item_activate_cb), self);
  g_signal_connect(quit_item, "activate",
                   G_CALLBACK(quit_menu_item_activate_cb), self);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), show_item);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), separator);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit_item);
  gtk_widget_show_all(menu);
  app_indicator_set_menu(self->indicator, GTK_MENU(menu));
}

static void set_tray_timer_state(MyApplication* self,
                                 gboolean enabled,
                                 const gchar* title,
                                 const gchar* subtitle) {
  ensure_tray_indicator(self);
  if (self->indicator == nullptr) {
    return;
  }
  if (!enabled) {
    app_indicator_set_label(self->indicator, "", "");
    app_indicator_set_title(self->indicator, kAppDisplayName);
    app_indicator_set_status(self->indicator, APP_INDICATOR_STATUS_ACTIVE);
    set_persistent_timer_notification(self, FALSE);
    return;
  }

  g_autofree gchar* tooltip = g_strdup_printf("%s · 剩余 %s", subtitle, title);
  app_indicator_set_status(self->indicator, APP_INDICATOR_STATUS_ACTIVE);
  app_indicator_set_label(self->indicator, title, "00:00:00");
  app_indicator_set_title(self->indicator, tooltip);
  set_persistent_timer_notification(self, TRUE);
}

static void show_stage_notification(MyApplication* self,
                                    const gchar* title,
                                    const gchar* subtitle) {
  GDBusProxy* proxy = get_notifications_proxy(self);
  if (proxy == nullptr) {
    return;
  }

  g_autofree gchar* icon_path = find_app_icon_path();
  GVariantBuilder actions;
  g_variant_builder_init(&actions, G_VARIANT_TYPE("as"));

  GVariantBuilder hints;
  g_variant_builder_init(&hints, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&hints, "{sv}", "desktop-entry",
                        g_variant_new_string(APPLICATION_ID));
  g_variant_builder_add(&hints, "{sv}", "x-kde-origin-name",
                        g_variant_new_string(kAppDisplayName));
  g_variant_builder_add(&hints, "{sv}", "category",
                        g_variant_new_string("x-kde.event"));
  g_variant_builder_add(&hints, "{sv}", "urgency", g_variant_new_byte(1));
  if (icon_path != nullptr) {
    g_variant_builder_add(&hints, "{sv}", "image-path",
                          g_variant_new_string(icon_path));
  }

  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) response = g_dbus_proxy_call_sync(
      proxy, "Notify",
      g_variant_new("(susss@as@a{sv}i)", kAppDisplayName, 0,
                    kNotificationIcon, title, subtitle,
                    g_variant_builder_end(&actions),
                    g_variant_builder_end(&hints), 5000),
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (response == nullptr) {
    g_warning("Failed to send stage notification: %s", error->message);
  }
}

static void set_keep_screen_on(MyApplication* self, gboolean enabled) {
  if (enabled && self->keep_screen_on_cookie == 0) {
    self->keep_screen_on_cookie = gtk_application_inhibit(
        GTK_APPLICATION(self), self->window, GTK_APPLICATION_INHIBIT_IDLE,
        "番茄钟计时进行中");
  }
  if (enabled && self->screensaver_cookie == 0) {
    GDBusProxy* proxy = get_session_proxy(
        &self->screensaver_proxy, "org.freedesktop.ScreenSaver",
        "/org/freedesktop/ScreenSaver", "org.freedesktop.ScreenSaver");
    if (proxy != nullptr) {
      g_autoptr(GError) error = nullptr;
      g_autoptr(GVariant) response = g_dbus_proxy_call_sync(
          proxy, "Inhibit",
          g_variant_new("(ss)", kAppDisplayName, "番茄钟计时进行中"),
          G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
      if (response != nullptr) {
        g_variant_get(response, "(u)", &self->screensaver_cookie);
      } else {
        g_debug("Failed to inhibit screensaver: %s", error->message);
      }
    }
  }
  if (enabled && self->power_inhibit_cookie == 0) {
    GDBusProxy* proxy = get_session_proxy(
        &self->power_inhibit_proxy, "org.freedesktop.PowerManagement.Inhibit",
        "/org/freedesktop/PowerManagement/Inhibit",
        "org.freedesktop.PowerManagement.Inhibit");
    if (proxy != nullptr) {
      g_autoptr(GError) error = nullptr;
      g_autoptr(GVariant) response = g_dbus_proxy_call_sync(
          proxy, "Inhibit",
          g_variant_new("(ss)", kAppDisplayName, "番茄钟计时进行中"),
          G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
      if (response != nullptr) {
        g_variant_get(response, "(u)", &self->power_inhibit_cookie);
      } else {
        g_debug("Failed to inhibit power management: %s", error->message);
      }
    }
  }
  if (enabled) {
    return;
  }

  if (self->screensaver_cookie != 0 && self->screensaver_proxy != nullptr) {
    g_autoptr(GError) error = nullptr;
    g_dbus_proxy_call_sync(
        self->screensaver_proxy, "UnInhibit",
        g_variant_new("(u)", self->screensaver_cookie), G_DBUS_CALL_FLAGS_NONE,
        -1, nullptr, &error);
    if (error != nullptr) {
      g_debug("Failed to uninhibit screensaver: %s", error->message);
    }
    self->screensaver_cookie = 0;
  }
  if (self->power_inhibit_cookie != 0 && self->power_inhibit_proxy != nullptr) {
    g_autoptr(GError) error = nullptr;
    g_dbus_proxy_call_sync(
        self->power_inhibit_proxy, "UnInhibit",
        g_variant_new("(u)", self->power_inhibit_cookie),
        G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
    if (error != nullptr) {
      g_debug("Failed to uninhibit power management: %s", error->message);
    }
    self->power_inhibit_cookie = 0;
  }
  if (self->keep_screen_on_cookie != 0) {
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
  return value != nullptr && value[0] != '\0' &&
         std::strchr(value, '/') == nullptr;
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

static void set_window_icon(GtkWindow* window) {
  g_autofree gchar* icon_path = find_app_icon_path();
  if (icon_path != nullptr) {
    g_autoptr(GError) error = nullptr;
    gtk_window_set_icon_from_file(window, icon_path, &error);
    if (error == nullptr) {
      return;
    }
    g_warning("Failed to load app icon: %s", error->message);
  }
  gtk_window_set_icon_name(window, APPLICATION_ID);
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
  } else if (g_strcmp0(method, "showStageNotification") == 0) {
    show_stage_notification(self, string_argument(method_call, "title"),
                            string_argument(method_call, "subtitle"));
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
             g_strcmp0(method, "enterPictureInPicture") == 0) {
    respond_success(method_call, nullptr);
  } else if (g_strcmp0(method, "setPipState") == 0) {
    set_tray_timer_state(self, bool_argument(method_call, "enabled", FALSE),
                         string_argument(method_call, "title"),
                         string_argument(method_call, "subtitle"));
    respond_success(method_call, nullptr);
  } else {
    g_autoptr(GError) error = nullptr;
    if (!fl_method_call_respond_not_implemented(method_call, &error)) {
      g_warning("Failed to respond not implemented: %s", error->message);
    }
  }
}

static gboolean window_delete_event_cb(GtkWidget* widget,
                                       GdkEvent* event,
                                       gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (!self->window_close_hides) {
    return FALSE;
  }
  gtk_widget_hide(widget);
  return TRUE;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) {
    show_main_window(self);
    return;
  }

  ensure_tray_indicator(self);

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  set_window_icon(window);
  g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_event_cb),
                   self);

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
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
  g_application_hold(application);
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
  g_clear_object(&self->indicator);
  g_clear_object(&self->platform_channel);
  g_clear_object(&self->notifications_proxy);
  g_clear_object(&self->screensaver_proxy);
  g_clear_object(&self->power_inhibit_proxy);
  self->window = nullptr;
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

static void my_application_init(MyApplication* self) {
  self->window_close_hides = TRUE;
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_DEFAULT_FLAGS, nullptr));
}
