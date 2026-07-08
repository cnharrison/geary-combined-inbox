/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Builds the keyboard shortcut help overlay for the active shortcut scheme. */
internal class Application.ShortcutHelpOverlayBuilder : Geary.BaseObject {

    private Application.Configuration config;
    private ShortcutManager? manager;


    internal ShortcutHelpOverlayBuilder(Application.Configuration config,
                                        ShortcutManager? manager) {
        this.config = config;
        this.manager = manager;
    }

    internal static void show_for_window(Gtk.ApplicationWindow window,
                                         string section_name,
                                         Application.Configuration config,
                                         ShortcutManager? manager) {
        Gtk.ShortcutsWindow? overlay = new ShortcutHelpOverlayBuilder(
            config,
            manager
        ).build();
        if (overlay == null) {
            return;
        }

        window.set_help_overlay(overlay);
        overlay.section_name = section_name;
        overlay.show();
    }

    internal Gtk.ShortcutsWindow? build() {
        string ui = build_ui();
        var builder = new Gtk.Builder();
        try {
            builder.add_from_string(ui, ui.length);
        } catch (GLib.Error error) {
            warning("Could not build shortcut help overlay: %s", error.message);
            return null;
        }

        return builder.get_object("help_overlay") as Gtk.ShortcutsWindow;
    }

    internal string build_ui() {
        var builder = new StringBuilder();
        builder.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        builder.append("<interface>\n");
        builder.append("  <object class=\"GtkShortcutsWindow\" id=\"help_overlay\">\n");
        append_conversation_section(builder);
        append_composer_section(builder);
        builder.append("  </object>\n");
        builder.append("</interface>\n");
        return builder.str;
    }

    private void append_conversation_section(StringBuilder builder) {
        append_registry_section(
            builder,
            "conversation",
            _("Conversation Shortcuts"),
            false
        );
    }

    private void append_composer_section(StringBuilder builder) {
        append_registry_section(
            builder,
            "composer",
            _("Composer Shortcuts"),
            true
        );
    }

    private void append_registry_section(StringBuilder builder,
                                         string name,
                                         string title,
                                         bool composer_only) {
        append_section(builder, name, title);

        string? current_group = null;
        bool group_open = false;
        if (this.manager != null) {
            foreach (ShortcutEntry entry in this.manager.get_entries()) {
                if (!is_section_entry(entry, composer_only)) {
                    continue;
                }

                string accelerator = get_accelerator(entry);
                if (accelerator == "") {
                    continue;
                }

                if (current_group != entry.group) {
                    if (group_open) {
                        append_group_end(builder);
                    }
                    append_group(builder, get_group_title(entry.group));
                    current_group = entry.group;
                    group_open = true;
                }
                append_shortcut(builder, entry.title, accelerator);
            }
        }

        if (group_open) {
            append_group_end(builder);
        }
        append_section_end(builder);
    }

    private bool is_section_entry(ShortcutEntry entry, bool composer_only) {
        if (composer_only) {
            return entry.context == COMPOSER;
        }
        return entry.context != COMPOSER && entry.context != TEXT_EDITING;
    }

    private string get_accelerator(ShortcutEntry entry) {
        string[] accelerators = {};
        if (this.manager != null) {
            foreach (ShortcutBinding binding in this.manager.get_bindings(
                entry,
                this.config.keyboard_shortcut_scheme
            )) {
                accelerators += binding.to_string();
            }
        }
        return string.joinv(" ", accelerators);
    }

    private string get_group_title(string group) {
        switch (group) {
        case "General":
            return _("General");

        case "Mail Actions":
            return _("Mail Actions");

        case "Navigation":
            return _("Navigation");

        case "Search":
            return _("Search");

        case "View":
            return _("View");

        case "Actions":
            return _("Actions");

        case "Editing":
            return _("Editing");

        case "Rich text editing":
            return _("Rich text editing");

        default:
            return group;
        }
    }

    private void append_section(StringBuilder builder,
                                string name,
                                string title) {
        builder.append("    <child>\n");
        builder.append("      <object class=\"GtkShortcutsSection\">\n");
        append_property(builder, "visible", "True");
        append_property(builder, "section-name", name);
        append_property(builder, "title", title);
    }

    private void append_section_end(StringBuilder builder) {
        builder.append("      </object>\n");
        builder.append("    </child>\n");
    }

    private void append_group(StringBuilder builder, string title) {
        builder.append("        <child>\n");
        builder.append("          <object class=\"GtkShortcutsGroup\">\n");
        append_property(builder, "visible", "True");
        append_property(builder, "title", title);
    }

    private void append_group_end(StringBuilder builder) {
        builder.append("          </object>\n");
        builder.append("        </child>\n");
    }

    private void append_shortcut(StringBuilder builder,
                                 string title,
                                 string accelerator) {
        builder.append("            <child>\n");
        builder.append("              <object class=\"GtkShortcutsShortcut\">\n");
        append_property(builder, "visible", "True");
        append_property(builder, "title", title);
        append_property(builder, "accelerator", accelerator);
        builder.append("              </object>\n");
        builder.append("            </child>\n");
    }

    private void append_property(StringBuilder builder,
                                 string name,
                                 string value) {
        builder.append("                <property name=\"");
        builder.append(name);
        builder.append("\">");
        builder.append(Markup.escape_text(value));
        builder.append("</property>\n");
    }

}
