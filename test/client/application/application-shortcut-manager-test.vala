/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class Application.ShortcutManagerTest : TestCase {

    public ShortcutManagerTest() {
        base("Application.ShortcutManagerTest");
        add_test(
            "applies_classic_gtk_accelerators",
            applies_classic_gtk_accelerators
        );
        add_test(
            "finds_dispatch_only_shortcuts",
            finds_dispatch_only_shortcuts
        );
        add_test(
            "finds_dispatch_sequence_shortcuts",
            finds_dispatch_sequence_shortcuts
        );
        add_test(
            "suppresses_dispatch_in_text_focus",
            suppresses_dispatch_in_text_focus
        );
        add_test(
            "detects_classic_mail_action_fallbacks",
            detects_classic_mail_action_fallbacks
        );
        add_test(
            "custom_profile_uses_saved_bindings",
            custom_profile_uses_saved_bindings
        );
        add_test(
            "replaces_custom_bindings",
            replaces_custom_bindings
        );
        add_test(
            "resets_and_replaces_custom_profile",
            resets_and_replaces_custom_profile
        );
        add_test(
            "clears_and_resets_custom_bindings",
            clears_and_resets_custom_bindings
        );
        add_test(
            "replaces_custom_sequence_bindings",
            replaces_custom_sequence_bindings
        );
    }

    public void applies_classic_gtk_accelerators() throws GLib.Error {
        var application = new Gtk.Application(
            "org.gnome.Geary.ShortcutManagerTest",
            ApplicationFlags.DEFAULT_FLAGS
        );
        var manager = new ShortcutManager(application, new ShortcutRegistry());

        manager.apply_scheme(ShortcutScheme.CLASSIC_GEARY);
        assert_accels(application, "app.compose", { "<Ctrl>N" });
        assert_accels(application, "win.show-help-overlay", {
            "<Ctrl>F1",
            "<Ctrl>question"
        });
        assert_accels(application, "win.reply-conversation", {});

        manager.apply_scheme(ShortcutScheme.GMAIL);
        assert_accels(application, "app.compose", { "<Ctrl>N" });
        assert_accels(application, "win.reply-conversation", {});

        manager.apply_scheme(ShortcutScheme.CUSTOM);
        assert_accels(application, "app.compose", {});
    }

    public void finds_dispatch_only_shortcuts() throws GLib.Error {
        ShortcutManager manager = new_manager(
            "org.gnome.Geary.ShortcutManagerDispatchTest"
        );

        assert_dispatch(
            manager,
            ShortcutScheme.GMAIL,
            Gdk.Key.r,
            0,
            "mail.reply-sender"
        );
        assert_dispatch(
            manager,
            ShortcutScheme.GMAIL,
            Gdk.Key.I,
            Gdk.ModifierType.SHIFT_MASK,
            "mail.mark-read"
        );
        assert_dispatch(
            manager,
            ShortcutScheme.GMAIL,
            Gdk.Key.numbersign,
            Gdk.ModifierType.SHIFT_MASK,
            "mail.delete"
        );
        assert_dispatch(
            manager,
            ShortcutScheme.VIM,
            Gdk.Key.j,
            0,
            "mail.next-conversation"
        );
        assert(manager.get_dispatch_entry(
            ShortcutScheme.GMAIL,
            Gdk.Key.r,
            Gdk.ModifierType.CONTROL_MASK,
            null
        ) == null);
    }

    public void finds_dispatch_sequence_shortcuts() throws GLib.Error {
        ShortcutManager manager = new_manager(
            "org.gnome.Geary.ShortcutManagerSequenceTest"
        );
        string[] prefix = { "g" };
        string[] complete = { "g", "i" };
        string[] incomplete = { "g", "x" };

        assert(manager.has_dispatch_sequence_prefix(
            ShortcutScheme.GMAIL,
            prefix,
            null
        ));
        assert_dispatch_sequence(
            manager,
            ShortcutScheme.GMAIL,
            complete,
            "mail.select-inbox"
        );
        assert(!manager.has_dispatch_sequence_prefix(
            ShortcutScheme.GMAIL,
            incomplete,
            null
        ));
        assert(manager.get_dispatch_entry_for_sequence(
            ShortcutScheme.GMAIL,
            prefix,
            null
        ) == null);
    }

    public void suppresses_dispatch_in_text_focus() throws GLib.Error {
        ShortcutManager manager = new_manager(
            "org.gnome.Geary.ShortcutManagerSuppressTest"
        );
        var entry = new Gtk.Entry();
        var text = new Gtk.TextView();
        var button = new Gtk.Button.with_label("Button");

        assert(manager.get_dispatch_entry(
            ShortcutScheme.GMAIL,
            Gdk.Key.r,
            0,
            entry
        ) == null);
        assert(manager.get_dispatch_entry(
            ShortcutScheme.GMAIL,
            Gdk.Key.r,
            0,
            text
        ) == null);
        assert_dispatch(
            manager,
            ShortcutScheme.GMAIL,
            Gdk.Key.r,
            0,
            "mail.reply-sender",
            button
        );
    }

    public void custom_profile_uses_saved_bindings() throws GLib.Error {
        var application = new Gtk.Application(
            "org.gnome.Geary.ShortcutManagerCustomTest",
            ApplicationFlags.DEFAULT_FLAGS
        );
        var config = new Configuration(Client.SCHEMA_ID);
        config.reset_custom_shortcut_profile();
        var manager = new ShortcutManager(
            application,
            new ShortcutRegistry(),
            config
        );

        assert(!config.has_custom_shortcut_profile);
        assert(manager.ensure_custom_profile_from_scheme(ShortcutScheme.VIM));
        assert(config.has_custom_shortcut_profile);
        assert(config.custom_shortcut_profile_base == ShortcutScheme.VIM);
        assert_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.j,
            0,
            "mail.next-conversation"
        );

        manager.apply_scheme(ShortcutScheme.CUSTOM);
        assert_accels(application, "app.compose", { "<Ctrl>N" });
        assert(manager.is_classic_mail_action_fallback(
            ShortcutScheme.CUSTOM,
            Gdk.Key.r,
            Gdk.ModifierType.CONTROL_MASK,
            null
        ));

        assert(!manager.ensure_custom_profile_from_scheme(
            ShortcutScheme.CLASSIC_GEARY
        ));
        assert(config.custom_shortcut_profile_base == ShortcutScheme.VIM);
        assert_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.j,
            0,
            "mail.next-conversation"
        );

        manager.save_custom_profile_from_scheme(ShortcutScheme.CLASSIC_GEARY);
        assert(!manager.is_classic_mail_action_fallback(
            ShortcutScheme.CUSTOM,
            Gdk.Key.r,
            Gdk.ModifierType.CONTROL_MASK,
            null
        ));

        config.reset_custom_shortcut_profile();
    }

    public void replaces_custom_bindings() throws GLib.Error {
        var application = new Gtk.Application(
            "org.gnome.Geary.ShortcutManagerReplaceCustomTest",
            ApplicationFlags.DEFAULT_FLAGS
        );
        var config = new Configuration(Client.SCHEMA_ID);
        config.reset_custom_shortcut_profile();
        var manager = new ShortcutManager(
            application,
            new ShortcutRegistry(),
            config
        );

        manager.save_custom_profile_from_scheme(ShortcutScheme.VIM);
        config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;

        ShortcutEntry compose = require_entry(manager, "app.compose");
        var compose_binding = new ShortcutBinding({ "<Ctrl>M" });
        assert(manager.can_replace_custom_binding(compose, compose_binding));
        manager.replace_custom_binding(compose, compose_binding);
        assert_accels(application, "app.compose", { "<Ctrl>M" });

        ShortcutEntry reply = require_entry(manager, "mail.reply-sender");
        ShortcutEntry next_conversation = require_entry(
            manager,
            "mail.next-conversation"
        );
        var conflicting = new ShortcutBinding({ "j" });
        assert(manager.find_custom_binding_conflict(reply, conflicting) ==
               next_conversation);
        assert(!manager.can_replace_custom_binding(reply, conflicting));
        manager.replace_custom_binding(reply, conflicting);
        assert_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.j,
            0,
            "mail.next-conversation"
        );

        ShortcutEntry new_window = require_entry(manager, "app.new-window");
        var bare = new ShortcutBinding({ "x" });
        assert(!manager.can_replace_custom_binding(new_window, bare));

        config.reset_custom_shortcut_profile();
    }

    public void resets_and_replaces_custom_profile() throws GLib.Error {
        var application = new Gtk.Application(
            "org.gnome.Geary.ShortcutManagerResetCustomTest",
            ApplicationFlags.DEFAULT_FLAGS
        );
        var config = new Configuration(Client.SCHEMA_ID);
        config.reset_custom_shortcut_profile();
        var manager = new ShortcutManager(
            application,
            new ShortcutRegistry(),
            config
        );

        manager.save_custom_profile_from_scheme(ShortcutScheme.VIM);
        config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;
        manager.apply_scheme(ShortcutScheme.CUSTOM);

        ShortcutEntry compose = require_entry(manager, "app.compose");
        manager.replace_custom_binding(
            compose,
            new ShortcutBinding({ "<Ctrl>M" })
        );
        assert_accels(application, "app.compose", { "<Ctrl>M" });

        assert(manager.reset_custom_profile_to_base());
        assert(config.custom_shortcut_profile_base == ShortcutScheme.VIM);
        assert_accels(application, "app.compose", { "<Ctrl>N" });
        assert_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.j,
            0,
            "mail.next-conversation"
        );

        assert(manager.replace_custom_profile_from_scheme(ShortcutScheme.GMAIL));
        assert(config.custom_shortcut_profile_base == ShortcutScheme.GMAIL);
        assert_accels(application, "app.compose", { "<Ctrl>N" });
        assert_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.r,
            0,
            "mail.reply-sender"
        );
        assert_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.c,
            0,
            "app.compose"
        );

        config.reset_custom_shortcut_profile();
    }

    public void clears_and_resets_custom_bindings() throws GLib.Error {
        var application = new Gtk.Application(
            "org.gnome.Geary.ShortcutManagerClearCustomTest",
            ApplicationFlags.DEFAULT_FLAGS
        );
        var config = new Configuration(Client.SCHEMA_ID);
        config.reset_custom_shortcut_profile();
        var manager = new ShortcutManager(
            application,
            new ShortcutRegistry(),
            config
        );

        manager.save_custom_profile_from_scheme(ShortcutScheme.GMAIL);
        config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;
        manager.apply_scheme(ShortcutScheme.CUSTOM);

        ShortcutEntry compose = require_entry(manager, "app.compose");
        manager.replace_custom_binding(
            compose,
            new ShortcutBinding({ "<Ctrl>M" })
        );
        assert_accels(application, "app.compose", { "<Ctrl>M" });
        assert_no_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.c,
            0
        );

        assert(manager.reset_custom_bindings_to_base(compose));
        assert_accels(application, "app.compose", { "<Ctrl>N" });
        assert_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.c,
            0,
            "app.compose"
        );

        assert(manager.clear_custom_bindings(compose));
        assert_accels(application, "app.compose", {});
        assert_no_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.c,
            0
        );

        ShortcutEntry reply = require_entry(manager, "mail.reply-sender");
        manager.replace_custom_binding(
            reply,
            new ShortcutBinding({ "c" })
        );
        assert(manager.find_custom_reset_conflict(compose) == reply);
        assert(!manager.can_reset_custom_bindings(compose));
        assert(!manager.reset_custom_bindings_to_base(compose));
        assert_accels(application, "app.compose", {});
        assert_dispatch(
            manager,
            ShortcutScheme.CUSTOM,
            Gdk.Key.c,
            0,
            "mail.reply-sender"
        );

        config.reset_custom_shortcut_profile();
    }

    public void replaces_custom_sequence_bindings() throws GLib.Error {
        var application = new Gtk.Application(
            "org.gnome.Geary.ShortcutManagerCustomSequenceTest",
            ApplicationFlags.DEFAULT_FLAGS
        );
        var config = new Configuration(Client.SCHEMA_ID);
        config.reset_custom_shortcut_profile();
        var manager = new ShortcutManager(
            application,
            new ShortcutRegistry(),
            config
        );

        manager.save_custom_profile_from_scheme(ShortcutScheme.GMAIL);
        config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;

        ShortcutEntry select_inbox = require_entry(manager, "mail.select-inbox");
        assert_dispatch_sequence(
            manager,
            ShortcutScheme.CUSTOM,
            { "g", "i" },
            "mail.select-inbox"
        );

        var replacement = new ShortcutBinding({ "g", "s" });
        assert(manager.can_replace_custom_binding(select_inbox, replacement));
        manager.replace_custom_binding(select_inbox, replacement);
        assert(manager.has_dispatch_sequence_prefix(
            ShortcutScheme.CUSTOM,
            { "g" },
            null
        ));
        assert_dispatch_sequence(
            manager,
            ShortcutScheme.CUSTOM,
            { "g", "s" },
            "mail.select-inbox"
        );
        assert(manager.get_dispatch_entry_for_sequence(
            ShortcutScheme.CUSTOM,
            { "g", "i" },
            null
        ) == null);

        ShortcutEntry go_to_start = require_entry(manager, "mail.go-to-start");
        assert(manager.find_custom_binding_conflict(
            go_to_start,
            replacement
        ) == select_inbox);
        assert(!manager.can_replace_custom_binding(go_to_start, replacement));

        ShortcutEntry next_conversation = require_entry(
            manager,
            "mail.next-conversation"
        );
        var prefixed_by_next = new ShortcutBinding({ "j", "x" });
        assert(manager.find_custom_binding_conflict(
            select_inbox,
            prefixed_by_next
        ) == next_conversation);
        assert(!manager.can_replace_custom_binding(
            select_inbox,
            prefixed_by_next
        ));
        assert(!manager.can_replace_custom_binding(
            next_conversation,
            new ShortcutBinding({ "g", "n" })
        ));

        var ctrl_r_sequence = new ShortcutBinding({ "<Ctrl>R", "i" });
        assert(manager.can_replace_custom_binding(
            select_inbox,
            ctrl_r_sequence
        ));
        manager.replace_custom_binding(select_inbox, ctrl_r_sequence);
        assert(!manager.is_classic_mail_action_fallback(
            ShortcutScheme.CUSTOM,
            Gdk.Key.r,
            Gdk.ModifierType.CONTROL_MASK,
            null
        ));

        config.reset_custom_shortcut_profile();
    }

    public void detects_classic_mail_action_fallbacks() throws GLib.Error {
        ShortcutManager manager = new_manager(
            "org.gnome.Geary.ShortcutManagerFallbackTest"
        );
        var entry = new Gtk.Entry();

        assert(manager.is_classic_mail_action_fallback(
            ShortcutScheme.GMAIL,
            Gdk.Key.r,
            Gdk.ModifierType.CONTROL_MASK,
            null
        ));
        assert(manager.is_classic_mail_action_fallback(
            ShortcutScheme.VIM,
            Gdk.Key.R,
            Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK,
            null
        ));
        assert(!manager.is_classic_mail_action_fallback(
            ShortcutScheme.CLASSIC_GEARY,
            Gdk.Key.r,
            Gdk.ModifierType.CONTROL_MASK,
            null
        ));
        assert(!manager.is_classic_mail_action_fallback(
            ShortcutScheme.GMAIL,
            Gdk.Key.f,
            Gdk.ModifierType.CONTROL_MASK,
            null
        ));
        assert(!manager.is_classic_mail_action_fallback(
            ShortcutScheme.GMAIL,
            Gdk.Key.r,
            Gdk.ModifierType.CONTROL_MASK,
            entry
        ));
    }

    private ShortcutManager new_manager(string application_id) {
        return new ShortcutManager(
            new Gtk.Application(application_id, ApplicationFlags.DEFAULT_FLAGS),
            new ShortcutRegistry()
        );
    }

    private ShortcutEntry require_entry(ShortcutManager manager, string id) {
        ShortcutEntry? entry = manager.get_entry(id);
        assert(entry != null);
        return entry;
    }

    private void assert_accels(Gtk.Application application,
                               string action,
                               string[] expected) {
        string[] actual = application.get_accels_for_action(action);
        assert(actual.length == expected.length);
        for (int i = 0; i < expected.length; i++) {
            assert(actual[i] == normalize_accelerator(expected[i]));
        }
    }

    private void assert_dispatch(ShortcutManager manager,
                                 ShortcutScheme scheme,
                                 uint keyval,
                                 Gdk.ModifierType modifiers,
                                 string expected_id,
                                 Gtk.Widget? focus = null) {
        ShortcutEntry? entry = manager.get_dispatch_entry(
            scheme,
            keyval,
            modifiers,
            focus
        );
        assert(entry != null);
        assert(entry.id == expected_id);
    }

    private void assert_no_dispatch(ShortcutManager manager,
                                    ShortcutScheme scheme,
                                    uint keyval,
                                    Gdk.ModifierType modifiers,
                                    Gtk.Widget? focus = null) {
        assert(manager.get_dispatch_entry(
            scheme,
            keyval,
            modifiers,
            focus
        ) == null);
    }

    private void assert_dispatch_sequence(ShortcutManager manager,
                                          ShortcutScheme scheme,
                                          string[] strokes,
                                          string expected_id,
                                          Gtk.Widget? focus = null) {
        ShortcutEntry? entry = manager.get_dispatch_entry_for_sequence(
            scheme,
            strokes,
            focus
        );
        assert(entry != null);
        assert(entry.id == expected_id);
    }

    private string normalize_accelerator(string accelerator) {
        uint key;
        Gdk.ModifierType modifiers;
        Gtk.accelerator_parse(accelerator, out key, out modifiers);
        return Gtk.accelerator_name(key, modifiers);
    }

}
