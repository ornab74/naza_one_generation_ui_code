// LLM-CONTEXT:BEGIN
// FILE: linux/runner/my_application.cc
// ROLE: Owns my application behavior within the platform-shell subsystem.
// DOMAIN: platform-shell
// SECURITY-INVARIANT: Keep platform permissions and generated integration boundaries minimal and reproducible.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
#include "my_application.h"

#include <cstdlib>
#include <sys/stat.h>
#include <unistd.h>

#include <flutter_linux/flutter_linux.h>
#include <glib/gstdio.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gboolean flutter_software_renderer = FALSE;

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static gboolean env_value_is_true(const gchar* value) {
  return value != nullptr &&
         (g_strcmp0(value, "1") == 0 || g_strcmp0(value, "true") == 0 ||
          g_strcmp0(value, "TRUE") == 0 || g_strcmp0(value, "yes") == 0 ||
          g_strcmp0(value, "YES") == 0);
}

static gboolean has_linux_render_node() {
  GError* error = nullptr;
  GDir* directory = g_dir_open("/dev/dri", 0, &error);
  if (directory == nullptr) {
    if (error != nullptr) {
      g_error_free(error);
    }
    return FALSE;
  }

  gboolean found = FALSE;
  while (const gchar* name = g_dir_read_name(directory)) {
    if (g_str_has_prefix(name, "renderD")) {
      g_autofree gchar* path = g_build_filename("/dev/dri", name, nullptr);
      GStatBuf info;
      if (g_stat(path, &info) == 0 && S_ISCHR(info.st_mode) &&
          g_access(path, R_OK | W_OK) == 0) {
        found = TRUE;
        break;
      }
    }
  }
  g_dir_close(directory);
  return found;
}

static void queue_draw_child(GtkWidget* widget, gpointer user_data);

static void queue_draw_tree(GtkWidget* widget) {
  if (widget == nullptr) {
    return;
  }

  gtk_widget_queue_draw(widget);

  if (GTK_IS_CONTAINER(widget)) {
    gtk_container_foreach(GTK_CONTAINER(widget), queue_draw_child, nullptr);
  }
}

static void queue_draw_child(GtkWidget* widget, gpointer user_data) {
  (void)user_data;
  queue_draw_tree(widget);
}

static gboolean flutter_engine_switch_exists(const gchar* switch_value) {
  const gchar* raw_count = g_getenv("FLUTTER_ENGINE_SWITCHES");
  if (raw_count == nullptr || raw_count[0] == '\0') {
    return FALSE;
  }

  char* end = nullptr;
  const long count = std::strtol(raw_count, &end, 10);
  if (end == raw_count || count <= 0) {
    return FALSE;
  }

  for (long i = 1; i <= count; i++) {
    g_autofree gchar* key = g_strdup_printf("FLUTTER_ENGINE_SWITCH_%ld", i);
    const gchar* value = g_getenv(key);
    if (g_strcmp0(value, switch_value) == 0) {
      return TRUE;
    }
  }

  return FALSE;
}

static void append_flutter_engine_switch(const gchar* switch_value) {
  if (flutter_engine_switch_exists(switch_value)) {
    return;
  }

  long count = 0;
  const gchar* raw_count = g_getenv("FLUTTER_ENGINE_SWITCHES");
  if (raw_count != nullptr && raw_count[0] != '\0') {
    char* end = nullptr;
    const long parsed = std::strtol(raw_count, &end, 10);
    if (end != raw_count && parsed > 0) {
      count = parsed;
    }
  }

  const long next = count + 1;
  g_autofree gchar* key = g_strdup_printf("FLUTTER_ENGINE_SWITCH_%ld", next);
  g_autofree gchar* value_count = g_strdup_printf("%ld", next);
  g_setenv(key, switch_value, TRUE);
  g_setenv("FLUTTER_ENGINE_SWITCHES", value_count, TRUE);
}

static void configure_flutter_rendering() {
  flutter_software_renderer = FALSE;
  // The Linux embedder chooses kOpenGL vs kSoftware from
  // FLUTTER_LINUX_RENDERER before engine startup. Use Impeller on the
  // accelerated path: Skia's first GL program compile is the one-frame
  // shader jank reported by DevTools even after the app warm-up.
  //
  // Set NAZA_FLUTTER_SKIA=1 to keep the old Skia path for driver diagnostics.
  // Set NAZA_FLUTTER_SOFTWARE=1 as a compatibility fallback on systems whose
  // OpenGL surface does not present frames correctly.
  if (env_value_is_true(g_getenv("NAZA_FLUTTER_SOFTWARE"))) {
    flutter_software_renderer = TRUE;
    g_setenv("FLUTTER_LINUX_RENDERER", "software", TRUE);
    append_flutter_engine_switch("enable-impeller=false");
    append_flutter_engine_switch("enable-software-rendering=true");
    g_message("Naza One: using Flutter Linux software renderer (fallback)");
    return;
  }

  if (env_value_is_true(g_getenv("NAZA_FLUTTER_SKIA"))) {
    g_unsetenv("FLUTTER_LINUX_RENDERER");
    append_flutter_engine_switch("enable-impeller=false");
    g_message("Naza One: using Flutter Linux Skia renderer (diagnostic)");
    return;
  }

  // Impeller on a host with no DRM render node falls through to a software GL
  // stack while still paying the accelerated compositor overhead. That path
  // competes with CPU-only Gemma inference and presents as whole-window raster
  // jank. Select Flutter's direct software renderer automatically; explicit
  // Skia/software diagnostics above still take precedence.
  if (!has_linux_render_node()) {
    flutter_software_renderer = TRUE;
    g_setenv("FLUTTER_LINUX_RENDERER", "software", TRUE);
    append_flutter_engine_switch("enable-impeller=false");
    append_flutter_engine_switch("enable-software-rendering=true");
    g_message(
        "Naza One: no Linux render node; using Flutter software renderer");
    return;
  }

  g_unsetenv("FLUTTER_LINUX_RENDERER");
  append_flutter_engine_switch("enable-impeller=true");
  g_message("Naza One: using Flutter Linux accelerated Impeller renderer");
}

static gboolean redraw_flutter_view_tick_cb(GtkWidget* widget,
                                            GdkFrameClock* frame_clock,
                                            gpointer user_data) {
  (void)frame_clock;
  (void)user_data;

  if (gtk_widget_get_mapped(widget)) {
    queue_draw_tree(widget);
  }

  return G_SOURCE_CONTINUE;
}

static void install_render_damage_workaround(FlView* view) {
  // Flutter's Linux embedder renders into an internal GtkDrawingArea child.
  // On the affected setup, Flutter state and layer presentation happen, but
  // GTK/compositor damage does not reach the actual drawing area until the
  // window is moved/resized. Queueing only the outer FlView is not enough; walk
  // the subtree so the internal render area is invalidated too.
  //
  // Enable with NAZA_GTK_REDRAW=1 only if the software renderer still fails to
  // damage the internal drawing area on a particular GTK/compositor stack.
  if (!flutter_software_renderer ||
      !env_value_is_true(g_getenv("NAZA_GTK_REDRAW"))) {
    return;
  }

  gtk_widget_add_tick_callback(GTK_WIDGET(view), redraw_flutter_view_tick_cb,
                               nullptr, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

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
    gtk_header_bar_set_title(header_bar, "Naza One");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Naza One");
  }

  gtk_window_set_default_size(window, 1280, 720);

  configure_flutter_rendering();

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
  install_render_damage_workaround(view);
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

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
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
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
