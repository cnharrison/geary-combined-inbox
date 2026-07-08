/*
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class Application.ConfigurationTest : TestCase {

    private Configuration test_config = null;

    public ConfigurationTest() {
        base("ConfigurationTest");
        add_test("desktop_environment", desktop_environment);
        add_test("keyboard_shortcut_scheme", keyboard_shortcut_scheme);
        add_test("custom_shortcut_profile", custom_shortcut_profile);
        add_test(
            "migrates_single_key_shortcuts_to_gmail",
            migrates_single_key_shortcuts_to_gmail
        );
    }

    public override void set_up() {
        Environment.unset_variable("XDG_CURRENT_DESKTOP");
        reset_shortcut_settings();
        this.test_config = new Configuration(Client.SCHEMA_ID);
    }

    public void desktop_environment() throws Error {
        assert(this.test_config.desktop_environment ==
               Configuration.DesktopEnvironment.UNKNOWN);

        Environment.set_variable("XDG_CURRENT_DESKTOP", "BLARG", true);
        assert(this.test_config.desktop_environment ==
               Configuration.DesktopEnvironment.UNKNOWN);

        Environment.set_variable("XDG_CURRENT_DESKTOP", "Unity", true);
        assert(this.test_config.desktop_environment ==
               Configuration.DesktopEnvironment.UNITY);
    }

    public void keyboard_shortcut_scheme() throws Error {
        assert(this.test_config.keyboard_shortcut_scheme ==
               ShortcutScheme.CLASSIC_GEARY);

        ShortcutScheme[] schemes = {
            ShortcutScheme.GMAIL,
            ShortcutScheme.VIM
        };
        foreach (ShortcutScheme scheme in schemes) {
            this.test_config.keyboard_shortcut_scheme = scheme;
            assert(this.test_config.keyboard_shortcut_scheme == scheme);
        }

        this.test_config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;
        assert(this.test_config.keyboard_shortcut_scheme ==
               ShortcutScheme.CLASSIC_GEARY);

        var builder = new GLib.VariantBuilder(
            new GLib.VariantType("a{sv}")
        );
        builder.add(
            "{sv}",
            "app.compose",
            new GLib.Variant.strv({ "c" })
        );
        this.test_config.set_custom_shortcut_profile(builder.end());
        this.test_config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;
        assert(this.test_config.keyboard_shortcut_scheme == ShortcutScheme.CUSTOM);
    }

    public void custom_shortcut_profile() throws Error {
        assert(!this.test_config.has_custom_shortcut_profile);
        assert(this.test_config.custom_shortcut_profile_base ==
               ShortcutScheme.CLASSIC_GEARY);

        var builder = new GLib.VariantBuilder(
            new GLib.VariantType("a{sv}")
        );
        builder.add(
            "{sv}",
            "mail.next-conversation",
            new GLib.Variant.strv({ "j" })
        );
        this.test_config.set_custom_shortcut_profile(builder.end());
        this.test_config.custom_shortcut_profile_base = ShortcutScheme.VIM;
        assert(this.test_config.has_custom_shortcut_profile);
        assert(this.test_config.custom_shortcut_profile_base == ShortcutScheme.VIM);
        this.test_config.keyboard_shortcut_scheme = ShortcutScheme.CUSTOM;

        this.test_config.reset_custom_shortcut_profile();
        assert(!this.test_config.has_custom_shortcut_profile);
        assert(this.test_config.keyboard_shortcut_scheme ==
               ShortcutScheme.CLASSIC_GEARY);
        assert(this.test_config.custom_shortcut_profile_base ==
               ShortcutScheme.CLASSIC_GEARY);

        Settings settings = new Settings(Client.SCHEMA_ID);
        settings.set_string(
            Configuration.KEYBOARD_SHORTCUT_SCHEME,
            ShortcutScheme.CUSTOM.to_setting()
        );
        this.test_config = new Configuration(Client.SCHEMA_ID);
        assert(this.test_config.keyboard_shortcut_scheme ==
               ShortcutScheme.CLASSIC_GEARY);
    }

    public void migrates_single_key_shortcuts_to_gmail() throws Error {
        reset_shortcut_settings();

        Settings settings = new Settings(Client.SCHEMA_ID);
        settings.set_boolean(Configuration.SINGLE_KEY_SHORTCUTS, true);

        this.test_config = new Configuration(Client.SCHEMA_ID);
        assert(this.test_config.keyboard_shortcut_scheme == ShortcutScheme.GMAIL);
        assert(settings.get_boolean(
            Configuration.KEYBOARD_SHORTCUT_SCHEME_MIGRATED
        ));
    }

    private void reset_shortcut_settings() {
        Settings settings = new Settings(Client.SCHEMA_ID);
        settings.reset(Configuration.SINGLE_KEY_SHORTCUTS);
        settings.reset(Configuration.KEYBOARD_SHORTCUT_SCHEME);
        settings.reset(Configuration.KEYBOARD_SHORTCUT_SCHEME_MIGRATED);
        settings.reset(Configuration.KEYBOARD_SHORTCUT_CUSTOM_PROFILE);
        settings.reset(Configuration.KEYBOARD_SHORTCUT_CUSTOM_PROFILE_BASE);
    }

}
