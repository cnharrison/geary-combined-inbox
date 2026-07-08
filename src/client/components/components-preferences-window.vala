/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class Components.PreferencesWindow : Hdy.PreferencesWindow {


    private const string ACTION_CLOSE = "preferences-close";

    private const ActionEntry[] WINDOW_ACTIONS = {
        { Action.Window.CLOSE, on_close },
        { ACTION_CLOSE, on_close },
    };

    private enum ShortcutSchemeRowValue {
        CLASSIC_GEARY,
        GMAIL,
        VIM
    }

    private enum ShortcutSchemeRowValueWithCustom {
        CLASSIC_GEARY,
        GMAIL,
        VIM,
        CUSTOM
    }

    private class ShortcutCaptureDialog : Gtk.Dialog {

        public Application.ShortcutBinding? binding { get; private set; }

        private Application.ShortcutManager manager;
        private Application.ShortcutEntry entry;
        private Gtk.Label captured_label;
        private Gtk.Label status_label;
        private string[] captured_strokes = {};


        public ShortcutCaptureDialog(Gtk.Window parent,
                                     Application.ShortcutManager manager,
                                     Application.ShortcutEntry entry) {
            Object(
                modal: true,
                title: _("Set Keyboard Shortcut"),
                transient_for: parent
            );
            this.manager = manager;
            this.entry = entry;

            add_button(_("Cancel"), Gtk.ResponseType.CANCEL);
            add_button(_("Set"), Gtk.ResponseType.OK);
            set_response_sensitive(Gtk.ResponseType.OK, false);

            var content = (Gtk.Box) get_content_area();
            content.border_width = 18;
            content.spacing = 12;

            string instruction_text = entry.allow_sequence
                ? _("Press the new shortcut or key sequence for “%s”, then click Set.")
                : _("Press the new shortcut for “%s”.");
            var instructions = new Gtk.Label(
                instruction_text.printf(entry.title)
            );
            instructions.halign = Gtk.Align.START;
            instructions.wrap = true;
            content.add(instructions);

            this.captured_label = new Gtk.Label(_("No shortcut captured"));
            this.captured_label.halign = Gtk.Align.START;
            content.add(this.captured_label);

            this.status_label = new Gtk.Label("");
            this.status_label.halign = Gtk.Align.START;
            this.status_label.wrap = true;
            content.add(this.status_label);

            show_all();
        }

        public override bool key_press_event(Gdk.EventKey event) {
            if (is_modifier_key(event.keyval)) {
                return true;
            }

            string stroke = this.manager.get_event_stroke(
                event.keyval,
                event.state
            );
            if (this.entry.allow_sequence) {
                this.captured_strokes += stroke;
            } else {
                this.captured_strokes = { stroke };
            }
            this.binding = new Application.ShortcutBinding(
                this.captured_strokes
            );
            update_status();
            return true;
        }

        private void update_status() {
            Application.ShortcutBinding? binding = this.binding;
            if (binding == null) {
                return;
            }
            this.captured_label.label = binding.to_string();

            Application.ShortcutEntry? conflict =
                this.manager.find_custom_binding_conflict(
                    this.entry,
                    binding
                );
            if (conflict != null) {
                this.status_label.label = _("Already used for “%s”.").printf(
                    conflict.title
                );
                set_response_sensitive(Gtk.ResponseType.OK, false);
                return;
            }

            bool valid = this.manager.can_replace_custom_binding(
                this.entry,
                binding
            );
            this.status_label.label = valid
                ? _("Ready to set")
                : _("This shortcut cannot be used for this action.");
            set_response_sensitive(Gtk.ResponseType.OK, valid);
        }

        private bool is_modifier_key(uint keyval) {
            switch (keyval) {
            case Gdk.Key.Shift_L:
            case Gdk.Key.Shift_R:
            case Gdk.Key.Control_L:
            case Gdk.Key.Control_R:
            case Gdk.Key.Alt_L:
            case Gdk.Key.Alt_R:
            case Gdk.Key.Meta_L:
            case Gdk.Key.Meta_R:
            case Gdk.Key.Super_L:
            case Gdk.Key.Super_R:
                return true;

            default:
                return false;
            }
        }

    }

    private class ShortcutEditorWindow : Hdy.PreferencesWindow {

        private Application.ShortcutManager manager;
        private Gee.List<Hdy.ActionRow> shortcut_rows =
            new Gee.ArrayList<Hdy.ActionRow>();
        private Gee.List<Application.ShortcutEntry> shortcut_entries =
            new Gee.ArrayList<Application.ShortcutEntry>();
        private Hdy.ActionRow? reset_all_row = null;


        public ShortcutEditorWindow(PreferencesWindow parent,
                                    Application.ShortcutManager manager) {
            Object(
                application: parent.application,
                default_width: 720,
                default_height: 640,
                modal: true,
                title: _("Keyboard Shortcuts"),
                transient_for: parent
            );
            this.manager = manager;

            add_shortcuts_page();
        }

        private void add_shortcuts_page() {
            var page = new Hdy.PreferencesPage();
            /// Translators: Preferences page title
            page.title = _("Keyboard Shortcuts");
            page.icon_name = "preferences-desktop-keyboard-shortcuts-symbolic";

            add_profile_group(page);

            string? current_group = null;
            Hdy.PreferencesGroup? group = null;
            foreach (Application.ShortcutEntry entry in this.manager.get_entries()) {
                if (!entry.editable) {
                    continue;
                }

                if (current_group != entry.group) {
                    group = add_shortcut_group(page, entry.group);
                    current_group = entry.group;
                }
                add_shortcut_row(group, entry);
            }

            page.show_all();
            add(page);
        }

        private void add_profile_group(Hdy.PreferencesPage page) {
            var group = new Hdy.PreferencesGroup();
            group.title = _("Custom Profile");
            page.add(group);

            this.reset_all_row = new Hdy.ActionRow();
            this.reset_all_row.title = _("Reset All Shortcuts");
            this.reset_all_row.activatable = true;
            update_reset_all_row();
            this.reset_all_row.activated.connect(() => reset_custom_profile());
            group.add(this.reset_all_row);

            Application.ShortcutScheme[] schemes = {
                Application.ShortcutScheme.CLASSIC_GEARY,
                Application.ShortcutScheme.GMAIL,
                Application.ShortcutScheme.VIM
            };
            foreach (Application.ShortcutScheme scheme in schemes) {
                group.add(create_replace_profile_row(scheme));
            }
        }

        private Hdy.ActionRow create_replace_profile_row(
            Application.ShortcutScheme scheme
        ) {
            var row = new Hdy.ActionRow();
            row.title = _("Replace with %s Shortcuts").printf(
                shortcut_scheme_name(scheme)
            );
            row.subtitle = _("Discard Custom edits and copy this preset");
            row.activatable = true;
            row.activated.connect(() => replace_custom_profile(scheme));
            return row;
        }

        private Hdy.PreferencesGroup add_shortcut_group(
            Hdy.PreferencesPage page,
            string group_name
        ) {
            var group = new Hdy.PreferencesGroup();
            group.title = shortcut_group_display_name(group_name);
            page.add(group);
            return group;
        }

        private void add_shortcut_row(Hdy.PreferencesGroup group,
                                      Application.ShortcutEntry entry) {
            var row = new Hdy.ActionRow();
            row.title = entry.title;
            row.subtitle = get_shortcut_summary(entry);
            row.activatable = true;
            row.subtitle_lines = 2;
            row.activated.connect(() => edit_shortcut(entry, row));
            row.add(create_shortcut_row_buttons(entry, row));
            this.shortcut_entries.add(entry);
            this.shortcut_rows.add(row);
            group.add(row);
        }

        private Gtk.Widget create_shortcut_row_buttons(
            Application.ShortcutEntry entry,
            Hdy.ActionRow row
        ) {
            var buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            buttons.valign = Gtk.Align.CENTER;

            var reset_button = new Gtk.Button.with_label(_("Reset"));
            reset_button.tooltip_text = _(
                "Restore this action to its base preset shortcut"
            );
            reset_button.clicked.connect(() => reset_shortcut(entry, row));
            buttons.add(reset_button);

            var clear_button = new Gtk.Button.with_label(_("Clear"));
            clear_button.tooltip_text = _("Remove the shortcut for this action");
            clear_button.clicked.connect(() => clear_shortcut(entry, row));
            buttons.add(clear_button);

            return buttons;
        }

        private void reset_custom_profile() {
            if (!confirm_reset_custom_profile()) {
                return;
            }

            if (this.manager.reset_custom_profile_to_base()) {
                update_reset_all_row();
                refresh_shortcut_rows();
            }
        }

        private void replace_custom_profile(Application.ShortcutScheme scheme) {
            if (!confirm_replace_custom_profile(scheme)) {
                return;
            }

            if (this.manager.replace_custom_profile_from_scheme(scheme)) {
                update_reset_all_row();
                refresh_shortcut_rows();
            }
        }

        private bool confirm_reset_custom_profile() {
            Application.ShortcutScheme base_scheme =
                this.manager.get_custom_profile_base();
            var dialog = new ConfirmationDialog(
                this,
                _("Reset Custom shortcuts?"),
                _("This will discard your Custom shortcut edits and restore the %s defaults.").printf(
                    shortcut_scheme_name(base_scheme)
                ),
                _("Reset"),
                "destructive-action"
            );
            dialog.set_focus_response(Gtk.ResponseType.CANCEL);
            return dialog.run() == Gtk.ResponseType.OK;
        }

        private bool confirm_replace_custom_profile(
            Application.ShortcutScheme scheme
        ) {
            var dialog = new ConfirmationDialog(
                this,
                _("Replace Custom shortcuts?"),
                _("This will discard your Custom shortcut edits and copy the %s preset.").printf(
                    shortcut_scheme_name(scheme)
                ),
                _("Replace"),
                "destructive-action"
            );
            dialog.set_focus_response(Gtk.ResponseType.CANCEL);
            return dialog.run() == Gtk.ResponseType.OK;
        }

        private void update_reset_all_row() {
            if (this.reset_all_row == null) {
                return;
            }

            this.reset_all_row.subtitle = _(
                "Restore Custom to the %s defaults"
            ).printf(
                shortcut_scheme_name(this.manager.get_custom_profile_base())
            );
        }

        private void refresh_shortcut_rows() {
            for (int i = 0; i < this.shortcut_rows.size; i++) {
                refresh_shortcut_row(
                    this.shortcut_rows[i],
                    this.shortcut_entries[i]
                );
            }
        }

        private void reset_shortcut(Application.ShortcutEntry entry,
                                    Hdy.ActionRow row) {
            Application.ShortcutEntry? conflict =
                this.manager.find_custom_reset_conflict(entry);
            if (conflict != null) {
                show_reset_conflict(entry, conflict);
                return;
            }

            if (this.manager.reset_custom_bindings_to_base(entry)) {
                refresh_shortcut_row(row, entry);
            }
        }

        private void clear_shortcut(Application.ShortcutEntry entry,
                                    Hdy.ActionRow row) {
            if (this.manager.clear_custom_bindings(entry)) {
                refresh_shortcut_row(row, entry);
            }
        }

        private void show_reset_conflict(Application.ShortcutEntry entry,
                                         Application.ShortcutEntry conflict) {
            var dialog = new ErrorDialog(
                this,
                _("Cannot reset “%s”").printf(entry.title),
                _("The restored shortcut is already used for “%s”.").printf(
                    conflict.title
                )
            );
            dialog.run();
        }

        private void refresh_shortcut_row(Hdy.ActionRow row,
                                          Application.ShortcutEntry entry) {
            row.subtitle = get_shortcut_summary(entry);
        }

        private void edit_shortcut(Application.ShortcutEntry entry,
                                   Hdy.ActionRow row) {
            var dialog = new ShortcutCaptureDialog(this, this.manager, entry);
            int response = dialog.run();
            Application.ShortcutBinding? binding = dialog.binding;
            dialog.destroy();

            if (response == Gtk.ResponseType.OK && binding != null) {
                this.manager.replace_custom_binding(entry, binding);
                refresh_shortcut_row(row, entry);
            }
        }

        private string get_shortcut_summary(Application.ShortcutEntry entry) {
            string[] bindings = {};
            foreach (Application.ShortcutBinding binding in
                     this.manager.get_bindings(
                         entry,
                         Application.ShortcutScheme.CUSTOM
                     )) {
                bindings += binding.to_string();
            }
            return bindings.length > 0
                ? string.joinv(", ", bindings)
                : _("Not set");
        }

    }

    private class PluginRow : Hdy.ActionRow {

        private Peas.PluginInfo plugin;
        private Application.PluginManager plugins;
        private Gtk.Switch sw = new Gtk.Switch();


        public PluginRow(Peas.PluginInfo plugin,
                         Application.PluginManager plugins) {
            this.plugin = plugin;
            this.plugins = plugins;

            this.sw.active = plugin.is_loaded();
            this.sw.notify["active"].connect_after(() => update_plugin());
            this.sw.valign = CENTER;

            this.title = plugin.get_name();
            this.subtitle = plugin.get_description();
            this.activatable_widget = this.sw;
            this.add(this.sw);

            plugins.plugin_activated.connect((info) => {
                    if (this.plugin == info) {
                        this.sw.active = true;
                    }
                });
            plugins.plugin_deactivated.connect((info) => {
                    if (this.plugin == info) {
                        this.sw.active = false;
                    }
                });
            plugins.plugin_error.connect((info) => {
                    if (this.plugin == info) {
                        this.sw.active = false;
                        this.sw.sensitive = false;
                    }
                });
        }

        private void update_plugin() {
            if (this.sw.active && !this.plugin.is_loaded()) {
                bool loaded = false;
                try {
                    loaded = this.plugins.load_optional(this.plugin);
                } catch (GLib.Error err) {
                    warning(
                        "Plugin %s not able to be loaded: %s",
                        plugin.get_name(), err.message
                    );
                }
                if (!loaded) {
                    this.sw.active = false;
                }
            } else if (!sw.active && this.plugin.is_loaded()) {
                bool unloaded = false;
                try {
                    unloaded = this.plugins.unload_optional(this.plugin);
                } catch (GLib.Error err) {
                    warning(
                        "Plugin %s not able to be loaded: %s",
                        plugin.get_name(), err.message
                    );
                }
                if (!unloaded) {
                    this.sw.active = true;
                }
            }
        }

    }


    public static void add_accelerators(Application.Client app) {
        app.add_window_accelerators(ACTION_CLOSE, { "Escape" } );
    }


    /** Returns the window's associated client application instance. */
    public new Application.Client? application {
        get { return (Application.Client) base.get_application(); }
        set { base.set_application(value); }
    }

    private Application.PluginManager plugins;


    public PreferencesWindow(Application.MainWindow parent,
                             Application.PluginManager plugins) {
        Object(
            application: parent.application,
            default_width: 800,
            default_height: 600,
            transient_for: parent
        );
        this.plugins = plugins;

        add_general_pane();
        add_plugin_pane();
    }

    private void add_general_pane() {
        var autoselect = new Gtk.Switch();
        autoselect.valign = CENTER;

        var autoselect_row = new Hdy.ActionRow();
        /// Translators: Preferences label
        autoselect_row.title = _("_Automatically select next message");
        autoselect_row.use_underline = true;
        autoselect_row.activatable_widget = autoselect;
        autoselect_row.add(autoselect);

        var display_preview = new Gtk.Switch();
        display_preview.valign = CENTER;

        var display_preview_row = new Hdy.ActionRow();
        /// Translators: Preferences label
        display_preview_row.title = _("_Display conversation preview");
        display_preview_row.use_underline = true;
        display_preview_row.activatable_widget = display_preview;
        display_preview_row.add(display_preview);

        var shortcuts_row = new Hdy.ComboRow();
        /// Translators: Preferences label
        shortcuts_row.title = _("_Keyboard shortcuts");
        shortcuts_row.tooltip_text = _(
            "Choose the active keyboard shortcut scheme"
        );
        shortcuts_row.use_underline = true;
        shortcuts_row.set_for_enum(
            typeof(ShortcutSchemeRowValue),
            shortcut_scheme_display_name
        );

        var customize_shortcuts_row = new Hdy.ActionRow();
        /// Translators: Preferences label
        customize_shortcuts_row.title = _("Customize Shortcuts…");
        customize_shortcuts_row.subtitle = _(
            "Start with the active shortcut scheme and save it as Custom"
        );
        customize_shortcuts_row.activatable = true;

        var startup_notifications = new Gtk.Switch();
        startup_notifications.valign = CENTER;

        var startup_notifications_row = new Hdy.ActionRow();
        /// Translators: Preferences label
        startup_notifications_row.title = _("_Watch for new mail when closed");
        startup_notifications_row.use_underline = true;
        /// Translators: Preferences tooltip
        startup_notifications_row.tooltip_text = _(
            "Geary will keep running after all windows are closed"
        );
        startup_notifications_row.activatable_widget = startup_notifications;
        startup_notifications_row.add(startup_notifications);

        var trust_images = new Gtk.Switch();
        trust_images.valign = CENTER;

        var trust_images_row = new Hdy.ActionRow();
        /// Translators: Preferences label
        trust_images_row.title = _("_Always load images");
        trust_images_row.subtitle = _("Showing remote images allows the sender to track you");
        trust_images_row.use_underline = true;
        trust_images_row.activatable_widget = trust_images;
        trust_images_row.add(trust_images);

        var unset_html_colors = new Gtk.Switch();
        unset_html_colors.valign = CENTER;

        var unset_html_colors_row = new Hdy.ActionRow();
        /// Translators: Preferences label
        unset_html_colors_row.title = _("_Override the original colors in HTML emails");
        unset_html_colors_row.subtitle = _("Overrides the original colors in HTML messages to integrate better with the app theme. Requires restart.");
        unset_html_colors_row.use_underline = true;
        unset_html_colors_row.activatable_widget = unset_html_colors;
        unset_html_colors_row.add(unset_html_colors);

        var group = new Hdy.PreferencesGroup();
        /// Translators: Preferences group title
        //group.title = _("General");
        /// Translators: Preferences group description
        //group.description = _("General application preferences");
        group.add(autoselect_row);
        group.add(display_preview_row);
        group.add(shortcuts_row);
        group.add(customize_shortcuts_row);
        group.add(startup_notifications_row);
        group.add(trust_images_row);
        group.add(unset_html_colors_row);

        var page = new Hdy.PreferencesPage();
        /// Translators: Preferences page title
        page.title = _("Preferences");
        page.icon_name = "preferences-other-symbolic";
        page.add(group);
        page.show_all();

        add(page);

        GLib.SimpleActionGroup window_actions = new GLib.SimpleActionGroup();
        window_actions.add_action_entries(WINDOW_ACTIONS, this);
        insert_action_group(Action.Window.GROUP_NAME, window_actions);

        Application.Client? application = this.application;
        if (application != null) {
            Application.Configuration config = application.config;
            config.bind(
                Application.Configuration.AUTOSELECT_KEY,
                autoselect,
                "state"
            );
            config.bind(
                Application.Configuration.DISPLAY_PREVIEW_KEY,
                display_preview,
                "state"
            );
            bind_shortcut_scheme_row(shortcuts_row, config);
            bind_customize_shortcuts_row(
                customize_shortcuts_row,
                config,
                application.shortcut_manager,
                this
            );
            config.bind(
                Application.Configuration.RUN_IN_BACKGROUND_KEY,
                startup_notifications,
                "state"
            );
            config.bind_with_mapping(
                Application.Configuration.IMAGES_TRUSTED_DOMAINS,
                trust_images,
                "state",
                (GLib.SettingsBindGetMappingShared) settings_trust_images_getter,
                (GLib.SettingsBindSetMappingShared) settings_trust_images_setter
            );
            config.bind(
                Application.Configuration.UNSET_HTML_COLORS,
                unset_html_colors,
                "state"
            );
        }
    }

    private void add_plugin_pane() {
        var group = new Hdy.PreferencesGroup();
        /// Translators: Preferences group title
        //group.title = _("Plugins");
        /// Translators: Preferences group description
        //group.description = _("Optional features for Geary");

        Application.Client? application = this.application;
        if (application != null) {
            foreach (Peas.PluginInfo plugin in
                     this.plugins.get_optional_plugins()) {
                group.add(new PluginRow(plugin, this.plugins));
            }
        }

        var page = new Hdy.PreferencesPage();
        /// Translators: Preferences page title
        page.title = _("Plugins");
        page.icon_name = "application-x-addon-symbolic";
        page.add(group);
        page.show_all();

        add(page);
    }

    private void on_close() {
        close();
    }

    private static void bind_shortcut_scheme_row(
        Hdy.ComboRow row,
        Application.Configuration config
    ) {
        bool syncing = true;
        bool custom_visible = sync_shortcut_scheme_row(row, config, false);
        syncing = false;

        row.notify["selected-index"].connect(() => {
            if (syncing) {
                return;
            }

            Application.ShortcutScheme scheme = shortcut_scheme_from_index(
                row.selected_index,
                config.has_custom_shortcut_profile
            );
            if (config.keyboard_shortcut_scheme != scheme) {
                config.keyboard_shortcut_scheme = scheme;
            }
        });
        config.notify[Application.Configuration.KEYBOARD_SHORTCUT_SCHEME].connect(
            () => {
                syncing = true;
                custom_visible = sync_shortcut_scheme_row(
                    row,
                    config,
                    custom_visible
                );
                syncing = false;
            }
        );
        config.settings.changed[
            Application.Configuration.KEYBOARD_SHORTCUT_CUSTOM_PROFILE
        ].connect(() => {
            syncing = true;
            custom_visible = sync_shortcut_scheme_row(
                row,
                config,
                custom_visible
            );
            syncing = false;
        });
    }

    private static void bind_customize_shortcuts_row(
        Hdy.ActionRow row,
        Application.Configuration config,
        Application.ShortcutManager? manager,
        PreferencesWindow parent
    ) {
        row.sensitive = manager != null;
        sync_customize_shortcuts_row(row, config);
        config.settings.changed[
            Application.Configuration.KEYBOARD_SHORTCUT_CUSTOM_PROFILE
        ].connect(() => sync_customize_shortcuts_row(row, config));

        row.activated.connect(() => {
            if (manager == null) {
                return;
            }

            manager.ensure_custom_profile_from_scheme(
                config.keyboard_shortcut_scheme
            );
            config.keyboard_shortcut_scheme = Application.ShortcutScheme.CUSTOM;
            new ShortcutEditorWindow(parent, manager).present();
        });
    }

    private static void sync_customize_shortcuts_row(
        Hdy.ActionRow row,
        Application.Configuration config
    ) {
        row.subtitle = config.has_custom_shortcut_profile
            ? _("Edit your saved Custom shortcut profile")
            : _("Start with the active shortcut scheme and save it as Custom");
    }

    private static bool sync_shortcut_scheme_row(
        Hdy.ComboRow row,
        Application.Configuration config,
        bool custom_visible
    ) {
        bool should_show_custom = config.has_custom_shortcut_profile;
        if (custom_visible != should_show_custom) {
            row.set_for_enum(
                should_show_custom
                    ? typeof(ShortcutSchemeRowValueWithCustom)
                    : typeof(ShortcutSchemeRowValue),
                shortcut_scheme_display_name
            );
            custom_visible = should_show_custom;
        }

        int index = shortcut_scheme_to_index(
            config.keyboard_shortcut_scheme,
            custom_visible
        );
        if (row.selected_index != index) {
            row.selected_index = index;
        }
        return custom_visible;
    }

    private static string shortcut_scheme_display_name(
        Hdy.EnumValueObject value
    ) {
        switch ((ShortcutSchemeRowValueWithCustom) value.get_value()) {
        case ShortcutSchemeRowValueWithCustom.CLASSIC_GEARY:
            return shortcut_scheme_name(
                Application.ShortcutScheme.CLASSIC_GEARY
            );

        case ShortcutSchemeRowValueWithCustom.GMAIL:
            return shortcut_scheme_name(Application.ShortcutScheme.GMAIL);

        case ShortcutSchemeRowValueWithCustom.VIM:
            return shortcut_scheme_name(Application.ShortcutScheme.VIM);

        case ShortcutSchemeRowValueWithCustom.CUSTOM:
            return shortcut_scheme_name(Application.ShortcutScheme.CUSTOM);

        default:
            assert_not_reached();
        }
    }

    private static string shortcut_scheme_name(Application.ShortcutScheme scheme) {
        switch (scheme) {
        case Application.ShortcutScheme.CLASSIC_GEARY:
            /// Translators: Keyboard shortcut scheme name in Preferences
            return _("Classic Geary");

        case Application.ShortcutScheme.GMAIL:
            /// Translators: Keyboard shortcut scheme name in Preferences
            return _("Gmail");

        case Application.ShortcutScheme.VIM:
            /// Translators: Keyboard shortcut scheme name in Preferences
            return _("Vim");

        case Application.ShortcutScheme.CUSTOM:
            /// Translators: Keyboard shortcut scheme name in Preferences
            return _("Custom");

        default:
            assert_not_reached();
        }
    }

    private static int shortcut_scheme_to_index(
        Application.ShortcutScheme scheme,
        bool custom_visible
    ) {
        switch (scheme) {
        case Application.ShortcutScheme.GMAIL:
            return (int) ShortcutSchemeRowValue.GMAIL;

        case Application.ShortcutScheme.VIM:
            return (int) ShortcutSchemeRowValue.VIM;

        case Application.ShortcutScheme.CUSTOM:
            return custom_visible
                ? (int) ShortcutSchemeRowValueWithCustom.CUSTOM
                : (int) ShortcutSchemeRowValue.CLASSIC_GEARY;

        case Application.ShortcutScheme.CLASSIC_GEARY:
            return (int) ShortcutSchemeRowValue.CLASSIC_GEARY;

        default:
            assert_not_reached();
        }
    }

    private static string shortcut_group_display_name(string group) {
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

        default:
            return group;
        }
    }

    private static Application.ShortcutScheme shortcut_scheme_from_index(
        int index,
        bool custom_visible
    ) {
        switch ((ShortcutSchemeRowValueWithCustom) index) {
        case ShortcutSchemeRowValueWithCustom.CLASSIC_GEARY:
            return Application.ShortcutScheme.CLASSIC_GEARY;

        case ShortcutSchemeRowValueWithCustom.GMAIL:
            return Application.ShortcutScheme.GMAIL;

        case ShortcutSchemeRowValueWithCustom.VIM:
            return Application.ShortcutScheme.VIM;

        case ShortcutSchemeRowValueWithCustom.CUSTOM:
            if (custom_visible) {
                return Application.ShortcutScheme.CUSTOM;
            }
            assert_not_reached();

        default:
            assert_not_reached();
        }
    }

    private static bool settings_trust_images_getter(GLib.Value value, GLib.Variant variant, void* user_data) {
        var domains = variant.get_strv();
        value.set_boolean(domains.length > 0 && domains[0] == "*");
        return true;
    }

    private static GLib.Variant settings_trust_images_setter(GLib.Value value, GLib.VariantType expected_type, void* user_data) {
        var trusted = value.get_boolean();
        string[] values = {};
        if (trusted)
            values += "*";
        return new GLib.Variant.strv(values);
    }
}
