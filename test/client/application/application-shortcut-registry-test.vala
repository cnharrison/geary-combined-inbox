/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class Application.ShortcutRegistryTest : TestCase {

    public ShortcutRegistryTest() {
        base("Application.ShortcutRegistryTest");
        add_test("classic_mail_shortcuts", classic_mail_shortcuts);
        add_test("gmail_mail_shortcuts", gmail_mail_shortcuts);
        add_test("vim_navigation_shortcuts", vim_navigation_shortcuts);
        add_test("composer_shortcuts", composer_shortcuts);
        add_test(
            "built_in_shortcuts_have_no_conflicts",
            built_in_shortcuts_have_no_conflicts
        );
        add_test("detects_duplicate_conflicts", detects_duplicate_conflicts);
        add_test("unsupported_shortcuts_are_excluded", unsupported_shortcuts_are_excluded);
        add_test("help_overlay_builds", help_overlay_builds);
    }

    public void classic_mail_shortcuts() throws GLib.Error {
        var registry = new ShortcutRegistry();

        ShortcutEntry? reply = registry.get_entry("mail.reply-sender");
        assert(reply != null);
        assert(reply.title == "Reply to sender");
        assert(reply.context == ShortcutContext.MAIL);
        assert(reply.detailed_action_name == "win.reply-conversation");
        assert_binding(reply, ShortcutScheme.CLASSIC_GEARY, "<Ctrl>R");

        ShortcutEntry? mark_read = registry.get_entry("mail.mark-read");
        assert(mark_read != null);
        assert(mark_read.detailed_action_name == "win.mark-conversation-read");
        assert_binding(mark_read, ShortcutScheme.CLASSIC_GEARY, "<Ctrl><Shift>U");

        ShortcutEntry? mark_unread = registry.get_entry("mail.mark-unread");
        assert(mark_unread != null);
        assert(mark_unread.detailed_action_name == "win.mark-conversation-unread");
        assert_binding(mark_unread, ShortcutScheme.CLASSIC_GEARY, "<Ctrl>U");
    }

    public void gmail_mail_shortcuts() throws GLib.Error {
        var registry = new ShortcutRegistry();

        assert_binding(
            require_entry(registry, "app.compose"),
            ShortcutScheme.GMAIL,
            "c"
        );
        assert_binding(
            require_entry(registry, "mail.reply-sender"),
            ShortcutScheme.GMAIL,
            "r"
        );
        assert_no_binding(
            require_entry(registry, "mail.reply-sender"),
            ShortcutScheme.GMAIL,
            "<Ctrl>R"
        );
        assert_binding(
            require_entry(registry, "mail.mark-read"),
            ShortcutScheme.GMAIL,
            "<Shift>I"
        );
        assert_binding(
            require_entry(registry, "mail.mark-unread"),
            ShortcutScheme.GMAIL,
            "<Shift>U"
        );
        assert_binding(
            require_entry(registry, "mail.archive"),
            ShortcutScheme.GMAIL,
            "e"
        );
        assert_binding(
            require_entry(registry, "mail.delete"),
            ShortcutScheme.GMAIL,
            "numbersign"
        );
        assert_binding(
            require_entry(registry, "mail.find"),
            ShortcutScheme.GMAIL,
            "slash"
        );
        assert_binding(
            require_entry(registry, "mail.select-inbox"),
            ShortcutScheme.GMAIL,
            "g i"
        );
    }

    public void vim_navigation_shortcuts() throws GLib.Error {
        var registry = new ShortcutRegistry();

        assert_binding(
            require_entry(registry, "mail.previous-conversation"),
            ShortcutScheme.VIM,
            "k"
        );
        assert_binding(
            require_entry(registry, "mail.next-conversation"),
            ShortcutScheme.VIM,
            "j"
        );
        assert_binding(
            require_entry(registry, "mail.previous-pane"),
            ShortcutScheme.VIM,
            "h"
        );
        assert_binding(
            require_entry(registry, "mail.next-pane"),
            ShortcutScheme.VIM,
            "l"
        );
        assert_binding(
            require_entry(registry, "mail.go-to-start"),
            ShortcutScheme.VIM,
            "g g"
        );
        assert_binding(
            require_entry(registry, "mail.go-to-end"),
            ShortcutScheme.VIM,
            "<Shift>G"
        );
        assert_no_binding(
            require_entry(registry, "mail.reply-sender"),
            ShortcutScheme.VIM,
            "<Ctrl>R"
        );
        assert(require_entry(
            registry,
            "mail.reply-sender"
        ).get_default_bindings(ShortcutScheme.VIM).size == 0);
    }

    public void composer_shortcuts() throws GLib.Error {
        var registry = new ShortcutRegistry();

        ShortcutEntry? send = registry.get_entry("composer.send");
        assert(send != null);
        assert(send.title == "Send");
        assert(send.context == ShortcutContext.COMPOSER);
        assert(send.detailed_action_name == "win.send");
        assert_binding(send, ShortcutScheme.CLASSIC_GEARY, "<Ctrl>Return");
        assert_binding(send, ShortcutScheme.GMAIL, "<Ctrl>Return");
        assert_binding(send, ShortcutScheme.VIM, "<Ctrl>Return");

        ShortcutEntry? insert_image = registry.get_entry(
            "composer.insert-image"
        );
        assert(insert_image != null);
        assert(insert_image.detailed_action_name == "edt.insert-image");
        assert_binding(
            insert_image,
            ShortcutScheme.CLASSIC_GEARY,
            "<Ctrl>G"
        );
        assert_no_binding(
            insert_image,
            ShortcutScheme.CLASSIC_GEARY,
            "<Ctrl>I"
        );

        assert_binding(
            require_entry(registry, "composer.bold"),
            ShortcutScheme.CLASSIC_GEARY,
            "<Ctrl>B"
        );
        assert_binding(
            require_entry(registry, "composer.insert-link"),
            ShortcutScheme.CLASSIC_GEARY,
            "<Ctrl>L"
        );
    }

    public void built_in_shortcuts_have_no_conflicts() throws GLib.Error {
        var registry = new ShortcutRegistry();

        assert(registry.find_conflicts(ShortcutScheme.CLASSIC_GEARY).size == 0);
        assert(registry.find_conflicts(ShortcutScheme.GMAIL).size == 0);
        assert(registry.find_conflicts(ShortcutScheme.VIM).size == 0);
    }

    public void detects_duplicate_conflicts() throws GLib.Error {
        var registry = new ShortcutRegistry();
        registry.add_for_test(
            new ShortcutEntry(
                "test.conflict",
                "Conflict",
                "Test",
                ShortcutContext.MAIL,
                "win.conflict"
            ).add_default(ShortcutScheme.CLASSIC_GEARY, { "<Ctrl>R" })
        );

        Gee.List<ShortcutConflict> conflicts =
            registry.find_conflicts(ShortcutScheme.CLASSIC_GEARY);
        assert(conflicts.size == 1);
        assert(conflicts[0].binding.to_string() == "<Ctrl>R");
        assert(conflicts[0].first.id == "mail.reply-sender");
        assert(conflicts[0].second.id == "test.conflict");
    }

    public void unsupported_shortcuts_are_excluded() throws GLib.Error {
        var registry = new ShortcutRegistry();

        assert(registry.get_entry("mail.show-move-menu") == null);
        assert(registry.get_entries().size > 0);
    }

    public void help_overlay_builds() throws GLib.Error {
        var config = new Configuration(Client.SCHEMA_ID);
        var application = new Gtk.Application(
            "org.gnome.Geary.ShortcutHelpOverlayTest",
            ApplicationFlags.DEFAULT_FLAGS
        );
        var manager = new ShortcutManager(
            application,
            new ShortcutRegistry(),
            config
        );
        config.reset_custom_shortcut_profile();
        ShortcutScheme[] schemes = {
            ShortcutScheme.CLASSIC_GEARY,
            ShortcutScheme.GMAIL,
            ShortcutScheme.VIM
        };

        foreach (ShortcutScheme scheme in schemes) {
            config.keyboard_shortcut_scheme = scheme;
            var builder = new ShortcutHelpOverlayBuilder(config, manager);
            Gtk.ShortcutsWindow? overlay = builder.build();
            assert(overlay != null);
        }

        config.keyboard_shortcut_scheme = ShortcutScheme.CLASSIC_GEARY;
        string classic_ui = new ShortcutHelpOverlayBuilder(
            config,
            manager
        ).build_ui();
        assert(classic_ui.contains("Reply to sender"));
        assert(classic_ui.contains(
            "<property name=\"accelerator\">&lt;Ctrl&gt;R</property>"
        ));
        assert(classic_ui.contains("Composer Shortcuts"));
        assert(classic_ui.contains("Insert an image"));
        assert(classic_ui.contains("&lt;Ctrl&gt;G"));
        assert(!classic_ui.contains("Go to first conversation or message"));

        config.keyboard_shortcut_scheme = ShortcutScheme.VIM;
        string vim_ui = new ShortcutHelpOverlayBuilder(
            config,
            manager
        ).build_ui();
        assert(vim_ui.contains("Go to first conversation or message"));
        assert(vim_ui.contains("g g"));
        assert(!vim_ui.contains(
            "<property name=\"accelerator\">&lt;Ctrl&gt;R</property>"
        ));

        config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;
        assert(config.keyboard_shortcut_scheme == ShortcutScheme.CLASSIC_GEARY);

        manager.save_custom_profile_from_scheme(ShortcutScheme.GMAIL);
        config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;
        string custom_ui = new ShortcutHelpOverlayBuilder(
            config,
            manager
        ).build_ui();
        assert(custom_ui.contains("Reply to sender"));
        assert(custom_ui.contains(">r<"));
        assert(custom_ui.contains("Insert an image"));
        assert(custom_ui.contains("&lt;Ctrl&gt;G"));
        assert(!custom_ui.contains(
            "<property name=\"accelerator\">&lt;Ctrl&gt;R</property>"
        ));

        config.reset_custom_shortcut_profile();
        config.keyboard_shortcut_scheme = ShortcutScheme.CLASSIC_GEARY;
    }

    private ShortcutEntry require_entry(ShortcutRegistry registry, string id) {
        ShortcutEntry? entry = registry.get_entry(id);
        assert(entry != null);
        return entry;
    }

    private void assert_binding(ShortcutEntry entry,
                                ShortcutScheme scheme,
                                string expected) {
        foreach (ShortcutBinding binding in entry.get_default_bindings(scheme)) {
            if (binding.to_string() == expected) {
                return;
            }
        }
        assert_not_reached();
    }

    private void assert_no_binding(ShortcutEntry entry,
                                   ShortcutScheme scheme,
                                   string unexpected) {
        foreach (ShortcutBinding binding in entry.get_default_bindings(scheme)) {
            assert(binding.to_string() != unexpected);
        }
    }

}
