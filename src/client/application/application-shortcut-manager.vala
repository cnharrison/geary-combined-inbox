/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Applies keyboard shortcut schemes to GTK application accelerators. */
internal class Application.ShortcutManager : Geary.BaseObject {

    private const string GROUP_MAIL_ACTIONS = "Mail Actions";

    private Gtk.Application application;
    private ShortcutRegistry registry;
    private Configuration? config;


    public ShortcutManager(Gtk.Application application,
                           ShortcutRegistry? registry = null,
                           Configuration? config = null) {
        this.application = application;
        this.registry = registry ?? new ShortcutRegistry();
        this.config = config;
    }

    public Gee.Collection<ShortcutEntry> get_entries() {
        return this.registry.get_entries();
    }

    public ShortcutEntry? get_entry(string id) {
        return this.registry.get_entry(id);
    }

    public Gee.Collection<ShortcutBinding> get_bindings(ShortcutEntry entry,
                                                         ShortcutScheme scheme) {
        if (scheme == CUSTOM) {
            return get_custom_bindings(entry);
        }
        return entry.get_default_bindings(scheme);
    }

    public void save_custom_profile_from_scheme(ShortcutScheme source_scheme) {
        if (this.config == null || source_scheme == CUSTOM) {
            return;
        }
        this.config.set_custom_shortcut_profile(
            build_custom_profile(source_scheme)
        );
        this.config.custom_shortcut_profile_base = source_scheme;
    }

    public ShortcutScheme get_custom_profile_base() {
        assert(this.config != null);
        return this.config.custom_shortcut_profile_base;
    }

    public bool reset_custom_profile_to_base() {
        if (this.config == null || !this.config.has_custom_shortcut_profile) {
            return false;
        }

        return replace_custom_profile_from_scheme(
            this.config.custom_shortcut_profile_base
        );
    }

    public bool replace_custom_profile_from_scheme(ShortcutScheme source_scheme) {
        if (this.config == null || source_scheme == CUSTOM) {
            return false;
        }

        save_custom_profile_from_scheme(source_scheme);
        apply_custom_scheme_if_active();
        return this.config.has_custom_shortcut_profile;
    }

    public bool ensure_custom_profile_from_scheme(ShortcutScheme source_scheme) {
        if (this.config == null ||
            source_scheme == CUSTOM ||
            this.config.has_custom_shortcut_profile) {
            return false;
        }
        save_custom_profile_from_scheme(source_scheme);
        return this.config.has_custom_shortcut_profile;
    }

    public ShortcutBinding create_binding_from_event(
        uint keyval,
        Gdk.ModifierType modifiers
    ) {
        string[] strokes = { get_event_stroke(keyval, modifiers) };
        return new ShortcutBinding(strokes);
    }

    public string get_event_stroke(uint keyval, Gdk.ModifierType modifiers) {
        return normalize_key_stroke(keyval, modifiers);
    }

    public bool can_replace_custom_binding(ShortcutEntry entry,
                                           ShortcutBinding binding) {
        return this.config != null &&
            entry.editable &&
            is_binding_allowed_for_entry(entry, binding) &&
            find_custom_binding_conflict(entry, binding) == null;
    }

    public ShortcutEntry? find_custom_binding_conflict(ShortcutEntry target,
                                                       ShortcutBinding binding) {
        foreach (ShortcutEntry entry in this.registry.get_entries()) {
            if (entry == target || !contexts_overlap(target.context, entry.context)) {
                continue;
            }

            foreach (ShortcutBinding existing in get_bindings(entry, CUSTOM)) {
                if (bindings_conflict(binding, existing)) {
                    return entry;
                }
            }
        }
        return null;
    }

    public void replace_custom_binding(ShortcutEntry entry,
                                       ShortcutBinding binding) {
        if (!can_replace_custom_binding(entry, binding)) {
            return;
        }

        this.config.set_custom_shortcut_profile(
            build_custom_profile_with_override(entry, binding)
        );
        apply_custom_scheme_if_active();
    }

    public bool clear_custom_bindings(ShortcutEntry entry) {
        if (this.config == null || !entry.editable) {
            return false;
        }

        var bindings = new Gee.ArrayList<ShortcutBinding>();
        this.config.set_custom_shortcut_profile(
            build_custom_profile_with_replacement(entry, bindings)
        );
        apply_custom_scheme_if_active();
        return true;
    }

    public ShortcutEntry? find_custom_reset_conflict(ShortcutEntry target) {
        if (this.config == null || !target.editable) {
            return null;
        }

        foreach (ShortcutBinding binding in target.get_default_bindings(
            this.config.custom_shortcut_profile_base
        )) {
            ShortcutEntry? conflict = find_custom_binding_conflict(
                target,
                binding
            );
            if (conflict != null) {
                return conflict;
            }
        }
        return null;
    }

    public bool can_reset_custom_bindings(ShortcutEntry entry) {
        return this.config != null &&
            entry.editable &&
            find_custom_reset_conflict(entry) == null;
    }

    public bool reset_custom_bindings_to_base(ShortcutEntry entry) {
        if (!can_reset_custom_bindings(entry)) {
            return false;
        }

        this.config.set_custom_shortcut_profile(
            build_custom_profile_with_replacement(
                entry,
                entry.get_default_bindings(
                    this.config.custom_shortcut_profile_base
                )
            )
        );
        apply_custom_scheme_if_active();
        return true;
    }

    public void apply_scheme(ShortcutScheme scheme) {
        foreach (ShortcutEntry entry in this.registry.get_entries()) {
            if (!entry.use_gtk_accelerator) {
                continue;
            }

            this.application.set_accels_for_action(
                entry.detailed_action_name,
                get_accelerators(entry, scheme)
            );
        }
    }

    public ShortcutEntry? get_dispatch_entry(ShortcutScheme scheme,
                                             uint keyval,
                                             Gdk.ModifierType modifiers,
                                             Gtk.Widget? focus) {
        string[] strokes = { get_event_stroke(keyval, modifiers) };
        return get_dispatch_entry_for_sequence(scheme, strokes, focus);
    }

    public ShortcutEntry? get_dispatch_entry_for_sequence(
        ShortcutScheme scheme,
        string[] strokes,
        Gtk.Widget? focus
    ) {
        if (!can_dispatch_from_focus(focus)) {
            return null;
        }

        foreach (ShortcutEntry entry in this.registry.get_entries()) {
            foreach (ShortcutBinding binding in get_bindings(entry, scheme)) {
                if (can_dispatch_binding(binding) &&
                    bindings_match_sequence(binding, strokes)) {
                    return entry;
                }
            }
        }
        return null;
    }

    public bool has_dispatch_sequence_prefix(ShortcutScheme scheme,
                                             string[] strokes,
                                             Gtk.Widget? focus) {
        if (!can_dispatch_from_focus(focus)) {
            return false;
        }

        foreach (ShortcutEntry entry in this.registry.get_entries()) {
            foreach (ShortcutBinding binding in get_bindings(entry, scheme)) {
                if (can_dispatch_binding(binding) &&
                    binding_has_sequence_prefix(binding, strokes)) {
                    return true;
                }
            }
        }
        return false;
    }

    public bool can_dispatch_from_focus(Gtk.Widget? focus) {
        return !should_suppress_dispatch(focus);
    }

    public bool is_classic_mail_action_fallback(ShortcutScheme scheme,
                                                uint keyval,
                                                Gdk.ModifierType modifiers,
                                                Gtk.Widget? focus) {
        if (scheme == CLASSIC_GEARY || !can_dispatch_from_focus(focus)) {
            return false;
        }

        Gdk.ModifierType normalized_modifiers = normalize_modifiers(
            keyval,
            modifiers
        );
        if ((normalized_modifiers & Gdk.ModifierType.CONTROL_MASK) == 0) {
            return false;
        }

        string stroke = normalize_key_stroke(keyval, modifiers);
        if (scheme == CUSTOM && has_binding_starting_with_stroke(scheme, stroke)) {
            return false;
        }
        foreach (ShortcutEntry entry in this.registry.get_entries()) {
            if (entry.group != GROUP_MAIL_ACTIONS) {
                continue;
            }

            foreach (ShortcutBinding binding in entry.get_default_bindings(CLASSIC_GEARY)) {
                if (binding.strokes.length == 1 &&
                    normalize_binding_stroke(binding.strokes[0]) == stroke) {
                    return true;
                }
            }
        }
        return false;
    }

    private bool can_dispatch_binding(ShortcutBinding binding) {
        return !binding.can_use_gtk_accelerator();
    }

    private bool bindings_match_sequence(ShortcutBinding binding,
                                         string[] strokes) {
        return binding.strokes.length == strokes.length &&
            sequence_starts_with(binding, strokes);
    }

    private bool binding_has_sequence_prefix(ShortcutBinding binding,
                                             string[] strokes) {
        return binding.strokes.length > strokes.length &&
            sequence_starts_with(binding, strokes);
    }

    private bool sequence_starts_with(ShortcutBinding binding,
                                      string[] strokes) {
        if (strokes.length == 0) {
            return false;
        }

        for (int i = 0; i < strokes.length; i++) {
            if (normalize_binding_stroke(binding.strokes[i]) != strokes[i]) {
                return false;
            }
        }
        return true;
    }

    private void apply_custom_scheme_if_active() {
        if (this.config != null && this.config.keyboard_shortcut_scheme == CUSTOM) {
            apply_scheme(CUSTOM);
        }
    }

    private bool is_binding_allowed_for_entry(ShortcutEntry entry,
                                              ShortcutBinding binding) {
        if (binding.strokes.length == 1) {
            return entry.allow_bare_key || binding.can_use_gtk_accelerator();
        }

        return entry.allow_sequence && entry.allow_bare_key;
    }

    private bool contexts_overlap(ShortcutContext first,
                                  ShortcutContext second) {
        return first == second ||
            first == GLOBAL ||
            second == GLOBAL ||
            (first == MAIL && second == MAIL_SELECTION) ||
            (first == MAIL_SELECTION && second == MAIL);
    }

    private bool bindings_conflict(ShortcutBinding first,
                                   ShortcutBinding second) {
        return binding_starts_with(first, second) ||
            binding_starts_with(second, first);
    }

    private bool binding_starts_with(ShortcutBinding binding,
                                     ShortcutBinding prefix) {
        if (binding.strokes.length < prefix.strokes.length) {
            return false;
        }

        for (int i = 0; i < prefix.strokes.length; i++) {
            if (normalize_binding_stroke(binding.strokes[i]) !=
                normalize_binding_stroke(prefix.strokes[i])) {
                return false;
            }
        }
        return true;
    }

    private bool has_binding_starting_with_stroke(ShortcutScheme scheme,
                                                  string stroke) {
        foreach (ShortcutEntry entry in this.registry.get_entries()) {
            foreach (ShortcutBinding binding in get_bindings(entry, scheme)) {
                if (normalize_binding_stroke(binding.strokes[0]) == stroke) {
                    return true;
                }
            }
        }
        return false;
    }

    private string[] get_accelerators(ShortcutEntry entry,
                                      ShortcutScheme scheme) {
        string[] accelerators = {};
        foreach (ShortcutBinding binding in get_bindings(entry, scheme)) {
            if (binding.can_use_gtk_accelerator()) {
                accelerators += binding.to_string();
            }
        }
        return accelerators;
    }

    private GLib.Variant build_custom_profile(ShortcutScheme source_scheme) {
        var builder = new GLib.VariantBuilder(
            new GLib.VariantType("a{sv}")
        );
        foreach (ShortcutEntry entry in this.registry.get_entries()) {
            string[] serialized = {};
            foreach (ShortcutBinding binding in entry.get_default_bindings(
                source_scheme
            )) {
                serialized += binding.to_string();
            }
            if (serialized.length > 0) {
                builder.add(
                    "{sv}",
                    entry.id,
                    new GLib.Variant.strv(serialized)
                );
            }
        }
        return builder.end();
    }

    private GLib.Variant build_custom_profile_with_override(
        ShortcutEntry target,
        ShortcutBinding binding
    ) {
        var replacement = new Gee.ArrayList<ShortcutBinding>();
        replacement.add(binding);
        return build_custom_profile_with_replacement(target, replacement);
    }

    private GLib.Variant build_custom_profile_with_replacement(
        ShortcutEntry target,
        Gee.Collection<ShortcutBinding> replacement
    ) {
        var builder = new GLib.VariantBuilder(
            new GLib.VariantType("a{sv}")
        );
        foreach (ShortcutEntry entry in this.registry.get_entries()) {
            string[] serialized = {};
            Gee.Collection<ShortcutBinding> bindings = entry == target
                ? replacement
                : get_custom_bindings(entry);
            foreach (ShortcutBinding binding in bindings) {
                serialized += binding.to_string();
            }

            if (serialized.length > 0) {
                builder.add(
                    "{sv}",
                    entry.id,
                    new GLib.Variant.strv(serialized)
                );
            }
        }
        return builder.end();
    }

    private Gee.Collection<ShortcutBinding> get_custom_bindings(
        ShortcutEntry entry
    ) {
        var bindings = new Gee.ArrayList<ShortcutBinding>();
        if (this.config == null) {
            return bindings;
        }

        var dict = new GLib.VariantDict(
            this.config.get_custom_shortcut_profile()
        );
        GLib.Variant? value = dict.lookup_value(
            entry.id,
            new GLib.VariantType("as")
        );
        if (value == null) {
            return bindings;
        }

        foreach (string serialized in value.get_strv()) {
            string[] strokes = serialized.split(" ");
            if (strokes.length > 0) {
                bindings.add(new ShortcutBinding(strokes));
            }
        }
        return bindings;
    }

    private bool should_suppress_dispatch(Gtk.Widget? focus) {
        Gtk.Widget? widget = focus;
        while (widget != null) {
            if (is_text_input(widget)) {
                return true;
            }
            widget = widget.get_parent();
        }
        return false;
    }

    private bool is_text_input(Gtk.Widget widget) {
        return widget is Gtk.Editable ||
            widget is Gtk.TextView ||
            widget is Composer.WebView;
    }

    private string normalize_binding_stroke(string stroke) {
        uint keyval;
        Gdk.ModifierType modifiers;
        Gtk.accelerator_parse(stroke, out keyval, out modifiers);
        return normalize_key_stroke(keyval, modifiers);
    }

    private string normalize_key_stroke(uint keyval, Gdk.ModifierType modifiers) {
        return Gtk.accelerator_name(
            Gdk.keyval_to_lower(keyval),
            normalize_modifiers(keyval, modifiers)
        );
    }

    private Gdk.ModifierType normalize_modifiers(uint keyval,
                                                 Gdk.ModifierType modifiers) {
        Gdk.ModifierType normalized = (
            modifiers & Gtk.accelerator_get_default_mod_mask()
        );
        if ((normalized & Gdk.ModifierType.SHIFT_MASK) != 0 &&
            !is_shift_significant(keyval)) {
            normalized &= ~Gdk.ModifierType.SHIFT_MASK;
        }
        return normalized;
    }

    private bool is_shift_significant(uint keyval) {
        return Gdk.keyval_to_unicode(keyval) == 0 || is_ascii_letter(keyval);
    }

    private bool is_ascii_letter(uint keyval) {
        uint lower = Gdk.keyval_to_lower(keyval);
        return lower >= Gdk.Key.a && lower <= Gdk.Key.z;
    }

}
