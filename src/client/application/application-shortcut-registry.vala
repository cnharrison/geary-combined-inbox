/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Built-in keyboard shortcut schemes. */
public enum Application.ShortcutScheme {
    CLASSIC_GEARY,
    GMAIL,
    VIM,
    CUSTOM;

    public string to_setting() {
        switch (this) {
        case CLASSIC_GEARY:
            return "classic-geary";

        case GMAIL:
            return "gmail";

        case VIM:
            return "vim";

        case CUSTOM:
            return "custom";

        default:
            assert_not_reached();
        }
    }

    public static ShortcutScheme from_setting(string value) {
        switch (value) {
        case "classic-geary":
            return CLASSIC_GEARY;

        case "gmail":
            return GMAIL;

        case "vim":
            return VIM;

        case "custom":
            return CUSTOM;

        default:
            assert_not_reached();
        }
    }
}

/** UI context where a shortcut can be active. */
internal enum Application.ShortcutContext {
    GLOBAL,
    MAIL,
    MAIL_SELECTION,
    COMPOSER,
    TEXT_EDITING
}

/** A single shortcut binding, represented as one or more key strokes. */
internal class Application.ShortcutBinding : Geary.BaseObject {

    public string[] strokes { get; private set; }


    public ShortcutBinding(string[] strokes) {
        assert(strokes.length > 0);
        this.strokes = strokes;
    }

    public bool can_use_gtk_accelerator() {
        if (this.strokes.length != 1) {
            return false;
        }

        return has_non_shift_modifier(this.strokes[0]) ||
            is_safe_unmodified_key(this.strokes[0]);
    }

    public string to_string() {
        return string.joinv(" ", this.strokes);
    }

    private bool has_non_shift_modifier(string stroke) {
        string lower = stroke.down();
        return lower.contains("<ctrl>") ||
            lower.contains("<control>") ||
            lower.contains("<primary>") ||
            lower.contains("<alt>") ||
            lower.contains("<meta>") ||
            lower.contains("<super>");
    }

    private bool is_safe_unmodified_key(string stroke) {
        string lower = stroke.down();
        return is_function_key(lower) ||
            lower == "escape" ||
            lower == "back" ||
            lower == "forward";
    }

    private bool is_function_key(string lower) {
        return lower == "f1" ||
            lower == "f2" ||
            lower == "f3" ||
            lower == "f4" ||
            lower == "f5" ||
            lower == "f6" ||
            lower == "f7" ||
            lower == "f8" ||
            lower == "f9" ||
            lower == "f10" ||
            lower == "f11" ||
            lower == "f12";
    }

}

/** A conflict between two entries using the same shortcut binding. */
internal class Application.ShortcutConflict : Geary.BaseObject {

    public ShortcutBinding binding { get; private set; }
    public ShortcutEntry first { get; private set; }
    public ShortcutEntry second { get; private set; }


    public ShortcutConflict(ShortcutBinding binding,
                            ShortcutEntry first,
                            ShortcutEntry second) {
        this.binding = binding;
        this.first = first;
        this.second = second;
    }

}

/** Static metadata for an action that can have keyboard shortcuts. */
internal class Application.ShortcutEntry : Geary.BaseObject {

    public string id { get; private set; }
    public string title { get; private set; }
    public string group { get; private set; }
    public ShortcutContext context { get; private set; }
    public string detailed_action_name { get; private set; }
    public bool editable { get; private set; }
    public bool allow_bare_key { get; private set; }
    public bool allow_sequence { get; private set; }
    public bool use_gtk_accelerator { get; private set; default = false; }

    private Gee.List<ShortcutBinding> classic_bindings =
        new Gee.ArrayList<ShortcutBinding>();
    private Gee.List<ShortcutBinding> gmail_bindings =
        new Gee.ArrayList<ShortcutBinding>();
    private Gee.List<ShortcutBinding> vim_bindings =
        new Gee.ArrayList<ShortcutBinding>();
    private Gee.List<ShortcutBinding> empty_bindings =
        new Gee.ArrayList<ShortcutBinding>();


    public ShortcutEntry(string id,
                         string title,
                         string group,
                         ShortcutContext context,
                         string detailed_action_name,
                         bool editable = true,
                         bool allow_bare_key = false,
                         bool allow_sequence = false) {
        this.id = id;
        this.title = title;
        this.group = group;
        this.context = context;
        this.detailed_action_name = detailed_action_name;
        this.editable = editable;
        this.allow_bare_key = allow_bare_key;
        this.allow_sequence = allow_sequence;
    }

    public ShortcutEntry add_default(ShortcutScheme scheme, string[] strokes) {
        get_mutable_bindings(scheme).add(new ShortcutBinding(strokes));
        return this;
    }

    public ShortcutEntry set_gtk_accelerator() {
        this.use_gtk_accelerator = true;
        return this;
    }

    public Gee.Collection<ShortcutBinding> get_default_bindings(
        ShortcutScheme scheme
    ) {
        if (scheme == CUSTOM) {
            return this.empty_bindings.read_only_view;
        }

        return get_mutable_bindings(scheme).read_only_view;
    }

    private Gee.List<ShortcutBinding> get_mutable_bindings(
        ShortcutScheme scheme
    ) {
        switch (scheme) {
        case CLASSIC_GEARY:
            return this.classic_bindings;

        case GMAIL:
            return this.gmail_bindings;

        case VIM:
            return this.vim_bindings;

        default:
            assert_not_reached();
        }
    }

}

/** Registry of supported keyboard shortcut actions and built-in defaults. */
internal class Application.ShortcutRegistry : Geary.BaseObject {

    private const string GROUP_GENERAL = "General";
    private const string GROUP_MAIL_ACTIONS = "Mail Actions";
    private const string GROUP_NAVIGATION = "Navigation";
    private const string GROUP_SEARCH = "Search";
    private const string GROUP_VIEW = "View";
    private const string GROUP_COMPOSER_ACTIONS = "Actions";
    private const string GROUP_COMPOSER_EDITING = "Editing";
    private const string GROUP_COMPOSER_RICH_TEXT = "Rich text editing";

    private Gee.List<ShortcutEntry> ordered_entries =
        new Gee.ArrayList<ShortcutEntry>();
    private Gee.Map<string,ShortcutEntry> entries =
        new Gee.HashMap<string,ShortcutEntry>();


    public ShortcutRegistry() {
        add_global_shortcuts();
        add_mail_shortcuts();
        add_navigation_shortcuts();
        add_view_shortcuts();
        add_composer_shortcuts();
    }

    public ShortcutEntry? get_entry(string id) {
        return this.entries.get(id);
    }

    public Gee.Collection<ShortcutEntry> get_entries() {
        return this.ordered_entries.read_only_view;
    }

    public Gee.List<ShortcutConflict> find_conflicts(ShortcutScheme scheme) {
        var conflicts = new Gee.ArrayList<ShortcutConflict>();
        for (int i = 0; i < this.ordered_entries.size; i++) {
            ShortcutEntry first = this.ordered_entries[i];
            for (int j = i + 1; j < this.ordered_entries.size; j++) {
                ShortcutEntry second = this.ordered_entries[j];
                add_conflicts(scheme, first, second, conflicts);
            }
        }
        return conflicts;
    }

    internal ShortcutEntry add_for_test(ShortcutEntry entry) {
        return add(entry);
    }

    private ShortcutEntry add(ShortcutEntry entry) {
        assert(!this.entries.has_key(entry.id));
        this.ordered_entries.add(entry);
        this.entries.set(entry.id, entry);
        return entry;
    }

    private void add_conflicts(ShortcutScheme scheme,
                               ShortcutEntry first,
                               ShortcutEntry second,
                               Gee.Collection<ShortcutConflict> conflicts) {
        if (!contexts_overlap(first.context, second.context)) {
            return;
        }

        foreach (ShortcutBinding first_binding in first.get_default_bindings(scheme)) {
            foreach (ShortcutBinding second_binding in second.get_default_bindings(scheme)) {
                if (first_binding.to_string() == second_binding.to_string()) {
                    conflicts.add(new ShortcutConflict(
                        first_binding,
                        first,
                        second
                    ));
                }
            }
        }
    }

    private bool contexts_overlap(ShortcutContext first,
                                  ShortcutContext second) {
        return first == second ||
            first == GLOBAL ||
            second == GLOBAL ||
            (first == MAIL && second == MAIL_SELECTION) ||
            (first == MAIL_SELECTION && second == MAIL);
    }

    private ShortcutEntry add_default_for_all(ShortcutEntry entry,
                                             string[] strokes) {
        entry.add_default(CLASSIC_GEARY, strokes);
        entry.add_default(GMAIL, strokes);
        entry.add_default(VIM, strokes);
        return entry;
    }

    private ShortcutEntry add_composer_shortcut(string id,
                                                string title,
                                                string group,
                                                string detailed_action_name,
                                                string stroke) {
        return add_default_for_all(add(new ShortcutEntry(
            id,
            title,
            group,
            COMPOSER,
            detailed_action_name,
            false
        )), { stroke });
    }

    private void add_global_shortcuts() {
        add(new ShortcutEntry(
            "app.compose",
            _("New conversation"),
            GROUP_GENERAL,
            GLOBAL,
            Action.Application.prefix(Action.Application.COMPOSE),
            true,
            true
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "<Ctrl>N" })
            .add_default(GMAIL, { "<Ctrl>N" })
            .add_default(GMAIL, { "c" })
            .add_default(VIM, { "<Ctrl>N" });

        add(new ShortcutEntry(
            "app.new-window",
            _("Open a new window"),
            GROUP_GENERAL,
            GLOBAL,
            Action.Application.prefix(Action.Application.NEW_WINDOW),
            true
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "<Ctrl><Shift>N" })
            .add_default(GMAIL, { "<Ctrl><Shift>N" })
            .add_default(VIM, { "<Ctrl><Shift>N" });

        add(new ShortcutEntry(
            "app.quit",
            _("Quit"),
            GROUP_GENERAL,
            GLOBAL,
            Action.Application.prefix(Action.Application.QUIT),
            false
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "<Ctrl>Q" })
            .add_default(GMAIL, { "<Ctrl>Q" })
            .add_default(VIM, { "<Ctrl>Q" });

        add(new ShortcutEntry(
            "win.close",
            _("Close the current window"),
            GROUP_GENERAL,
            GLOBAL,
            Action.Window.prefix(Action.Window.CLOSE),
            false
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "<Ctrl>W" })
            .add_default(GMAIL, { "<Ctrl>W" })
            .add_default(VIM, { "<Ctrl>W" });

        add(new ShortcutEntry(
            "app.help",
            _("Show help"),
            GROUP_GENERAL,
            GLOBAL,
            Action.Application.prefix(Action.Application.HELP),
            false
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "F1" })
            .add_default(GMAIL, { "F1" })
            .add_default(VIM, { "F1" });

        add(new ShortcutEntry(
            "win.show-shortcuts",
            _("Show keyboard shortcuts"),
            GROUP_GENERAL,
            GLOBAL,
            Action.Window.prefix(Action.Window.SHOW_HELP_OVERLAY),
            false
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "<Ctrl>F1" })
            .add_default(CLASSIC_GEARY, { "<Ctrl>question" })
            .add_default(GMAIL, { "<Ctrl>F1" })
            .add_default(GMAIL, { "<Ctrl>question" })
            .add_default(VIM, { "<Ctrl>F1" })
            .add_default(VIM, { "<Ctrl>question" });

        add(new ShortcutEntry(
            "win.show-menu",
            _("Show menu"),
            GROUP_GENERAL,
            GLOBAL,
            Action.Window.prefix(Action.Window.SHOW_MENU),
            false
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "F10" })
            .add_default(GMAIL, { "F10" })
            .add_default(VIM, { "F10" });
    }

    private void add_mail_shortcuts() {
        add(new ShortcutEntry(
            "mail.reply-sender",
            _("Reply to sender"),
            GROUP_MAIL_ACTIONS,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_REPLY_CONVERSATION),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>R" })
            .add_default(GMAIL, { "r" });

        add(new ShortcutEntry(
            "mail.reply-all",
            _("Reply all"),
            GROUP_MAIL_ACTIONS,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_REPLY_ALL_CONVERSATION),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl><Shift>R" })
            .add_default(GMAIL, { "a" });

        add(new ShortcutEntry(
            "mail.forward",
            _("Forward"),
            GROUP_MAIL_ACTIONS,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_FORWARD_CONVERSATION),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>L" })
            .add_default(GMAIL, { "f" });

        add(new ShortcutEntry(
            "mail.mark-unread",
            _("Mark as unread"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_MARK_AS_UNREAD),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>U" })
            .add_default(GMAIL, { "<Shift>U" });

        add(new ShortcutEntry(
            "mail.mark-read",
            _("Mark as read"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_MARK_AS_READ),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl><Shift>U" })
            .add_default(GMAIL, { "<Shift>I" });

        add(new ShortcutEntry(
            "mail.star",
            _("Star"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_MARK_AS_STARRED),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>D" })
            .add_default(GMAIL, { "s" });

        add(new ShortcutEntry(
            "mail.unstar",
            _("Unstar"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_MARK_AS_UNSTARRED),
            true,
            true
        )).add_default(CLASSIC_GEARY, { "<Ctrl><Shift>D" });

        add(new ShortcutEntry(
            "mail.label",
            _("Label conversations"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_SHOW_COPY_MENU),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>B" })
            .add_default(GMAIL, { "l" });

        add(new ShortcutEntry(
            "mail.archive",
            _("Archive conversations"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_ARCHIVE_CONVERSATION),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>K" })
            .add_default(GMAIL, { "e" });

        add(new ShortcutEntry(
            "mail.trash",
            _("Move conversations to Trash"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_TRASH_CONVERSATION),
            true
        ))
            .add_default(CLASSIC_GEARY, { "BackSpace" })
            .add_default(CLASSIC_GEARY, { "Delete" })
            .add_default(CLASSIC_GEARY, { "KP_Delete" });

        add(new ShortcutEntry(
            "mail.delete",
            _("Delete conversations"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_DELETE_CONVERSATION),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Shift>BackSpace" })
            .add_default(CLASSIC_GEARY, { "<Shift>Delete" })
            .add_default(CLASSIC_GEARY, { "<Shift>KP_Delete" })
            .add_default(GMAIL, { "numbersign" });

        add(new ShortcutEntry(
            "mail.junk",
            _("Junk conversations"),
            GROUP_MAIL_ACTIONS,
            MAIL_SELECTION,
            Action.Window.prefix(Application.MainWindow.ACTION_TOGGLE_JUNK),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>J" })
            .add_default(GMAIL, { "exclam" });
    }

    private void add_navigation_shortcuts() {
        add(new ShortcutEntry(
            "mail.select-all",
            _("Select all conversations"),
            GROUP_NAVIGATION,
            MAIL,
            "win.select-all",
            true
        )).add_default(CLASSIC_GEARY, { "<Ctrl>A" });

        add(new ShortcutEntry(
            "mail.select-inbox",
            _("Go to inbox"),
            GROUP_NAVIGATION,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_SELECT_FIRST_INBOX),
            true,
            true,
            true
        )).add_default(GMAIL, { "g", "i" });

        add(new ShortcutEntry(
            "mail.previous-conversation",
            _("Select previous conversation"),
            GROUP_NAVIGATION,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_CONVERSATION_UP),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>comma" })
            .add_default(GMAIL, { "k" })
            .add_default(VIM, { "k" });

        add(new ShortcutEntry(
            "mail.next-conversation",
            _("Select next conversation"),
            GROUP_NAVIGATION,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_CONVERSATION_DOWN),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>period" })
            .add_default(GMAIL, { "j" })
            .add_default(VIM, { "j" });

        add(new ShortcutEntry(
            "mail.go-to-start",
            _("Go to first conversation or message"),
            GROUP_NAVIGATION,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_VIM_GO_TO_START),
            true,
            true,
            true
        )).add_default(VIM, { "g", "g" });

        add(new ShortcutEntry(
            "mail.go-to-end",
            _("Go to last conversation or message"),
            GROUP_NAVIGATION,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_VIM_GO_TO_END),
            true,
            true
        )).add_default(VIM, { "<Shift>G" });

        add(new ShortcutEntry(
            "mail.previous-pane",
            _("Go to previous pane"),
            GROUP_NAVIGATION,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_NAVIGATION_BACK),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Alt>Left" })
            .add_default(CLASSIC_GEARY, { "Back" })
            .add_default(VIM, { "h" });

        add(new ShortcutEntry(
            "mail.next-pane",
            _("Go to next pane"),
            GROUP_NAVIGATION,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_NAVIGATION_FORWARD),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Alt>Right" })
            .add_default(CLASSIC_GEARY, { "Forward" })
            .add_default(VIM, { "l" });

        for (int i = 1; i <= 9; i++) {
            add(new ShortcutEntry(
                "mail.select-inbox-%d".printf(i),
                /// Translators: Keyboard shortcut action label; %d is an inbox number.
                _("Select Inbox %d").printf(i),
                GROUP_NAVIGATION,
                MAIL,
                Action.Window.prefix(
                    Application.MainWindow.ACTION_SELECT_INBOX +
                    "(%d)".printf(i - 1)
                ),
                true
            ))
                .set_gtk_accelerator()
                .add_default(CLASSIC_GEARY, { "<Alt>%d".printf(i) })
                .add_default(GMAIL, { "<Alt>%d".printf(i) })
                .add_default(VIM, { "<Alt>%d".printf(i) });
        }

        add(new ShortcutEntry(
            "mail.search",
            _("Search for conversations"),
            GROUP_SEARCH,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_SEARCH),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>S" })
            .add_default(VIM, { "slash" });

        add(new ShortcutEntry(
            "mail.find",
            _("Find in current conversation"),
            GROUP_SEARCH,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_FIND_IN_CONVERSATION),
            true,
            true
        ))
            .add_default(CLASSIC_GEARY, { "<Ctrl>F" })
            .add_default(GMAIL, { "slash" });
    }

    private void add_composer_shortcuts() {
        add_composer_shortcut(
            "composer.send",
            _("Send"),
            GROUP_COMPOSER_ACTIONS,
            Action.Window.prefix("send"),
            "<Ctrl>Return"
        );
        add_composer_shortcut(
            "composer.add-attachment",
            _("Add attachment"),
            GROUP_COMPOSER_ACTIONS,
            Action.Window.prefix("add-attachment"),
            "<Ctrl>T"
        );
        add_composer_shortcut(
            "composer.detach",
            _("Detach composer window"),
            GROUP_COMPOSER_ACTIONS,
            Action.Window.prefix("detach"),
            "<Ctrl>D"
        );
        add_composer_shortcut(
            "composer.close",
            _("Close composer window"),
            GROUP_COMPOSER_ACTIONS,
            Action.Window.prefix("composer-close"),
            "Escape"
        );
        add_composer_shortcut(
            "composer.cut",
            _("Move selection to the clipboard"),
            GROUP_COMPOSER_EDITING,
            Action.Edit.prefix("cut"),
            "<Ctrl>X"
        );
        add_composer_shortcut(
            "composer.copy",
            _("Copy selection to clipboard"),
            GROUP_COMPOSER_EDITING,
            Action.Edit.prefix(Action.Edit.COPY),
            "<Ctrl>C"
        );
        add_composer_shortcut(
            "composer.paste",
            _("Paste from the clipboard"),
            GROUP_COMPOSER_EDITING,
            Action.Edit.prefix("paste"),
            "<Ctrl>V"
        );
        add_composer_shortcut(
            "composer.quote-text",
            _("Quote text"),
            GROUP_COMPOSER_EDITING,
            Action.Edit.prefix("outdent"),
            "<Ctrl>bracketleft"
        );
        add_composer_shortcut(
            "composer.unquote-text",
            _("Unquote text"),
            GROUP_COMPOSER_EDITING,
            Action.Edit.prefix("indent"),
            "<Ctrl>bracketright"
        );
        add_composer_shortcut(
            "composer.paste-without-formatting",
            _("Paste without formatting"),
            GROUP_COMPOSER_RICH_TEXT,
            Action.Edit.prefix("paste-without-formatting"),
            "<Ctrl><Shift>V"
        );
        add_composer_shortcut(
            "composer.bold",
            _("Bold text"),
            GROUP_COMPOSER_RICH_TEXT,
            Action.Edit.prefix("bold"),
            "<Ctrl>B"
        );
        add_composer_shortcut(
            "composer.italic",
            _("Italicize text"),
            GROUP_COMPOSER_RICH_TEXT,
            Action.Edit.prefix("italic"),
            "<Ctrl>I"
        );
        add_composer_shortcut(
            "composer.underline",
            _("Underline text"),
            GROUP_COMPOSER_RICH_TEXT,
            Action.Edit.prefix("underline"),
            "<Ctrl>U"
        );
        add_composer_shortcut(
            "composer.strikethrough",
            _("Strike text"),
            GROUP_COMPOSER_RICH_TEXT,
            Action.Edit.prefix("strikethrough"),
            "<Ctrl>K"
        );
        add_composer_shortcut(
            "composer.remove-formatting",
            _("Remove formatting"),
            GROUP_COMPOSER_RICH_TEXT,
            Action.Edit.prefix("remove-format"),
            "<Ctrl>space"
        );
        add_composer_shortcut(
            "composer.insert-image",
            _("Insert an image"),
            GROUP_COMPOSER_RICH_TEXT,
            Action.Edit.prefix("insert-image"),
            "<Ctrl>G"
        );
        add_composer_shortcut(
            "composer.insert-link",
            _("Insert a link"),
            GROUP_COMPOSER_RICH_TEXT,
            Action.Edit.prefix("insert-link"),
            "<Ctrl>L"
        );
    }

    private void add_view_shortcuts() {
        add(new ShortcutEntry(
            "view.zoom-in",
            _("Zoom in"),
            GROUP_VIEW,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_ZOOM + "('in')"),
            true
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "<Ctrl>equal" })
            .add_default(CLASSIC_GEARY, { "<Ctrl>plus" })
            .add_default(GMAIL, { "<Ctrl>equal" })
            .add_default(GMAIL, { "<Ctrl>plus" })
            .add_default(VIM, { "<Ctrl>equal" })
            .add_default(VIM, { "<Ctrl>plus" });

        add(new ShortcutEntry(
            "view.zoom-out",
            _("Zoom out"),
            GROUP_VIEW,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_ZOOM + "('out')"),
            true
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "<Ctrl>minus" })
            .add_default(GMAIL, { "<Ctrl>minus" })
            .add_default(VIM, { "<Ctrl>minus" });

        add(new ShortcutEntry(
            "view.zoom-normal",
            _("Reset zoom"),
            GROUP_VIEW,
            MAIL,
            Action.Window.prefix(Application.MainWindow.ACTION_ZOOM + "('normal')"),
            true
        ))
            .set_gtk_accelerator()
            .add_default(CLASSIC_GEARY, { "<Ctrl>0" })
            .add_default(GMAIL, { "<Ctrl>0" })
            .add_default(VIM, { "<Ctrl>0" });
    }

}
